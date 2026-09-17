param([Parameter(Mandatory=$true)][string]$Extension,[switch]$DiscoverOnly,[string[]]$Scope)
. "$PSScriptRoot/../../scripts/Common.ps1"
$w=Get-Workspace; $e=(Get-Extension $w $Extension).Config; $p=Get-Profile $w $e.profile

function Inspect-Root($Path,$Depth) {
    if (!(Test-Path -LiteralPath $Path -PathType Container)) { return }
    $queue=New-Object System.Collections.Queue; $queue.Enqueue(@($Path,0))
    while($queue.Count) {
        $pair=$queue.Dequeue(); $here=$pair[0]; $level=[int]$pair[1]
        $children=@(Get-ChildItem -LiteralPath $here -Force -ErrorAction SilentlyContinue)
        $markers=@($children | Where-Object { !$_.PSIsContainer -and ($_.Name -match '(?i)(\.sln$|\.csproj$|^package\.json$|^pom\.xml$|^web\.config$|\.aspx$|\.war$|\.dll$|\.cs$|\.java$)') } | Select-Object -ExpandProperty Name)
        if ($markers.Count) { [pscustomobject]@{path=$here;markers=$markers} }
        if ($level -lt $Depth) { foreach($d in $children) { if ($d.PSIsContainer -and $d.Name -notin $p.source.exclude -and !($d.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $queue.Enqueue(@($d.FullName,$level+1)) } } }
    }
}

$manifestDir=Join-Path $w.Path "sources/manifests/$Extension"
New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null
$accessPath=[string]$p.source.access_path
if ([string]::IsNullOrWhiteSpace($accessPath) -and $p.deployment.mode -eq 'local') { $accessPath=[string]$p.deployment.plm_local_path }
$roots=@($p.source.candidate_paths)
if ($p.source.auto_discover) {
    $roots+='\\vmware-host\Shared Folders'
    $roots+=@(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like '\\*' -or $_.Root -like '\\*' } | ForEach-Object { if ($_.DisplayRoot) {$_.DisplayRoot} else {$_.Root} })
    if (Get-Command Get-SmbMapping -ErrorAction SilentlyContinue) { $roots+=@(Get-SmbMapping -ErrorAction SilentlyContinue | Select-Object -ExpandProperty RemotePath) }
}
if ($accessPath) { $roots+=$accessPath }
$candidates=@(); $unavailable=@()
foreach($root in @($roots | Where-Object { $_ } | Select-Object -Unique)) {
    $available=$false
    try { $available=Test-Path -LiteralPath $root -ErrorAction Stop } catch { $available=$false }
    if ($available) { $candidates+=@(Inspect-Root $root ([Math]::Min(5,[Math]::Max(0,[int]$p.source.discovery_depth)))) }
    else { $unavailable+=$root }
}
$discovery=[ordered]@{schema_version=4;workspace_id=$w.Id;extension_id=$Extension;profile=$e.profile;generated_at=(Get-Date -Format o);deployment_mode=$p.deployment.mode;plm_local_path=$p.deployment.plm_local_path;access_path=$accessPath;candidates=$candidates;unavailable_roots=$unavailable}
Write-Config (Join-Path $manifestDir 'discovery.yaml') $discovery
if ($DiscoverOnly -or !$accessPath) { $candidates | Format-Table -AutoSize; Write-Output 'Discovery saved. Maintain source.access_path before syncing a VM or remote-server environment.'; return }

$src=(Get-Item -LiteralPath $accessPath).FullName.TrimEnd('\','/')
$dest=[IO.Path]::GetFullPath((Join-Path $w.Path "sources/mirror/$($e.profile)"))
if ($dest.StartsWith($src+'\',[StringComparison]::OrdinalIgnoreCase) -or $src.StartsWith($dest,[StringComparison]::OrdinalIgnoreCase) -or $src -eq $dest) { throw 'Source and mirror must not overlap.' }
if (!$Scope -and $p.source.PSObject.Properties['sync_scopes']) { $Scope=@($p.source.sync_scopes) }
$normalized=@()
foreach($item in @($Scope | Where-Object { $_ })) {
    $clean=$item.Replace('/','\').Trim('\')
    if ([IO.Path]::IsPathRooted($item) -or $clean.Split('\') -contains '..') { throw "Scope must be relative to source.access_path: $item" }
    $target=Join-Path $src $clean; Assert-Child $src $target
    if (!(Test-Path -LiteralPath $target)) { throw "Scope not found: $item" }
    $normalized+=$clean
}
if (!$normalized.Count) { $normalized=@('') }

$manifest=[ordered]@{schema_version=4;workspace_id=$w.Id;extension_id=$Extension;profile=$e.profile;generated_at=(Get-Date -Format o);deployment_mode=$p.deployment.mode;plm_local_path=$p.deployment.plm_local_path;access_path=$accessPath;scope=@($normalized);mode='read-only/scoped-incremental/no-delete';exclude=$p.source.exclude;exclude_files=$p.source.exclude_files;files=@();copied=0;unchanged=0;source_fingerprint=$null}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$queue=New-Object System.Collections.Queue
foreach($item in $normalized) { $queue.Enqueue($(if ($item) { Join-Path $src $item } else { $src })) }

function Sync-File($File) {
    $skip=$false; foreach($pattern in $p.source.exclude_files) { if ($File.Name -like $pattern) { $skip=$true } }; if ($skip) { return }
    $rel=$File.FullName.Substring($src.Length).TrimStart('\','/'); $target=Join-Path $dest $rel; Assert-Child $dest $target
    $hash=(Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash
    $same=(Test-Path -LiteralPath $target) -and ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -eq $hash)
    if (!$same) { New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null; Copy-Item -LiteralPath $File.FullName -Destination $target; if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $hash) { throw "Source changed during sync: $rel" }; $manifest.copied++ } else { $manifest.unchanged++ }
    $manifest.files+=@([ordered]@{path=$rel;sha256=$hash;length=$File.Length;modified_utc=$File.LastWriteTimeUtc.ToString('o')})
}

while($queue.Count) {
    $here=$queue.Dequeue(); $entry=Get-Item -LiteralPath $here
    if (!$entry.PSIsContainer) { Sync-File $entry; continue }
    foreach($child in Get-ChildItem -LiteralPath $here -Force) {
        if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        if ($child.PSIsContainer) { if ($child.Name -notin $p.source.exclude) { $queue.Enqueue($child.FullName) } }
        else { Sync-File $child }
    }
}
$sha=[Security.Cryptography.SHA256]::Create()
try { $bytes=[Text.Encoding]::UTF8.GetBytes((($manifest.files | Sort-Object path | ForEach-Object { $_.path+':'+$_.sha256 }) -join "`n")); $manifest.source_fingerprint=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') } finally { $sha.Dispose() }
$manifest['note']='Only files in this scoped manifest are current evidence. Mirror leftovers outside it may be stale.'
$manifestPath=Join-Path $manifestDir "source-manifest-$($e.profile).yaml"
Write-Config $manifestPath $manifest
Write-Output "Copied $($manifest.copied), unchanged $($manifest.unchanged), scope $($normalized -join ', '). Manifest: $manifestPath"
