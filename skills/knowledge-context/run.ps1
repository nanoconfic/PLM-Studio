param(
    [Parameter(Mandatory=$true)][string]$Extension,
    [string]$Facet='Auto'
)
. "$PSScriptRoot/../../scripts/Common.ps1"

function Get-FrontMatter([string]$Text) {
    $match=[regex]::Match($Text,'(?s)\A---\s*\r?\n(.*?)\r?\n---')
    if ($match.Success) { return $match.Groups[1].Value }
    $null
}

function Get-MetaValue([string]$Meta,[string]$Name) {
    $pattern='(?m)^\s*'+[regex]::Escape($Name)+':\s*"?([^"\r\n]+)'
    $match=[regex]::Match($Meta,$pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim().Trim("'") }
    $null
}

function Get-MetaProfiles([string]$Meta) {
    $match=[regex]::Match($Meta,'(?m)^\s*profiles:\s*\[(.*?)\]')
    if (!$match.Success) { return @() }
    @($match.Groups[1].Value.Split(',') | ForEach-Object {$_.Trim().Trim('"').Trim("'")} | Where-Object {$_})
}

function Same-Value($Expected,$Actual) {
    [string]::IsNullOrWhiteSpace([string]$Expected) -or ([string]$Expected).Equals([string]$Actual,[StringComparison]::OrdinalIgnoreCase)
}

$w=Get-Workspace
$ext=Get-Extension $w $Extension
$profileId=[string]$ext.Config.profile
$profile=Get-Profile $w $profileId

$allowedFacets=@('Auto','Style','Integration','Business','Data','Environment','All')
$selected=@($Facet.Split(',') | ForEach-Object {$_.Trim()} | Where-Object {$_})
foreach($name in $selected) { if ($name -notin $allowedFacets) { throw "Invalid facet: $name. Use Auto, Style, Integration, Business, Data, Environment or All." } }
if (!$selected.Count) { $selected=@('Auto') }
if ($selected -contains 'All') { $selected=@('All') }
elseif ($selected -contains 'Auto') {
    $selected=@('Style','Business')
    $mode=[string]$ext.Config.delivery.mode
    if ($mode -in @('embedded-static','backend') -or $ext.Config.target.module -or $ext.Config.target.menu -or $ext.Config.target.page) { $selected+='Integration' }
    if ($mode -eq 'backend' -or [string]$ext.Config.delivery.demo_data -notin @('','none','pending')) { $selected+='Data' }
    if ($mode -in @('embedded-static','backend')) { $selected+='Environment' }
    $selected=@($selected | Select-Object -Unique)
}

$categories=@{
    Style=@('page-style','design-token','layout','component','component-pattern','interaction','interaction-pattern','visual')
    Integration=@('mount-point','menu-mechanism','file-registration','source-structure','integration')
    Business=@('business-flow','permission','workflow','validation-rule')
    Data=@('data-model','demo-data','interface','write-operation','database')
    Environment=@('environment','browser','deployment','source-fingerprint')
}
$wanted=@()
foreach($name in $selected) { if ($categories.ContainsKey($name)) { $wanted+=@($categories[$name]) } }
$wanted=@($wanted | Select-Object -Unique)

$currentFingerprint=$null
$manifestCandidates=@(
    (Join-Path $w.Path "sources/manifests/$Extension/source-manifest-$profileId.yaml"),
    (Join-Path $w.Path "sources/manifests/source-manifest-$profileId.yaml")
)
foreach($manifestPath in $manifestCandidates) {
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        $manifestText=Read-Utf8Text $manifestPath
        $fingerprintMatch=[regex]::Match($manifestText,'"source_fingerprint"\s*:\s*"([A-Fa-f0-9]+)"')
        if ($fingerprintMatch.Success) { $currentFingerprint=$fingerprintMatch.Groups[1].Value.ToUpperInvariant(); break }
    }
}

$applicable=@(); $conditional=@(); $candidate=@(); $deprecated=@(); $skipped=@()
$patternRoot=Join-Path $w.Path 'knowledge/patterns'
if (Test-Path -LiteralPath $patternRoot) {
    foreach($file in Get-ChildItem -LiteralPath $patternRoot -File -Filter '*.md' | Sort-Object Name) {
        $content=Read-Utf8Text $file.FullName
        $meta=Get-FrontMatter $content
        if (!$meta) { continue }
        $id=Get-MetaValue $meta 'id'; $status=Get-MetaValue $meta 'status'; $categoryValue=Get-MetaValue $meta 'category'
        if ([string]::IsNullOrWhiteSpace($categoryValue)) { continue }
        $category=$categoryValue.ToLowerInvariant()
        if ($selected -notcontains 'All' -and $category -notin $wanted) { continue }
        $recordWorkspace=Get-MetaValue $meta 'workspace_id'
        $recordProduct=Get-MetaValue $meta 'product'
        $recordVersion=Get-MetaValue $meta 'version'
        $recordProfiles=@(Get-MetaProfiles $meta)
        $recordFingerprint=Get-MetaValue $meta 'source_fingerprint'
        $scopeMatches=(Same-Value $recordWorkspace $w.Id) -and (Same-Value $recordProduct $profile.product.name) -and (Same-Value $recordVersion $profile.product.version) -and (!$recordProfiles.Count -or $profileId -in $recordProfiles)
        $record=[pscustomobject]@{id=$id;status=$status;category=$category;path=$file.FullName.Substring($w.Path.Length).TrimStart('\').Replace('\','/');content=$content;fingerprint=$recordFingerprint}
        if (!$scopeMatches) { $skipped+=$record; continue }
        if ($status -eq 'Deprecated') { $deprecated+=$record; continue }
        if ($status -ne 'Verified') { $candidate+=$record; continue }
        if ($recordFingerprint -and !$currentFingerprint) { $conditional+=$record; continue }
        if ($recordFingerprint -and $recordFingerprint -ne $currentFingerprint) { $skipped+=$record; continue }
        $applicable+=$record
    }
}

$contradictionPaths=@()
foreach($record in @($applicable)+@($conditional)+@($candidate)) {
    foreach($match in [regex]::Matches($record.content,'knowledge/contradictions/[^\s\)"'']+\.md')) { $contradictionPaths+=$match.Value }
}
$contradictionPaths=@($contradictionPaths | Select-Object -Unique)

$lines=@()
$lines+='# Knowledge context'
$lines+="Extension: $Extension | Profile: $profileId | Product: $($profile.product.name) $($profile.product.version) | Facets: $($selected -join ', ')"
$lines+="Current source fingerprint: $(if($currentFingerprint){$currentFingerprint}else{'not available'})"
$lines+=''
$lines+='Rules injected into this task:'
$lines+='- Applicable Verified records are default design and implementation constraints.'
$lines+='- Candidate or fingerprint-unconfirmed records may guide questions and verification, but are not facts.'
$lines+='- Deprecated or scope-mismatched records must not be applied.'
$lines+='- If the user explicitly requires a deviation, identify it and preserve new evidence instead of silently overriding knowledge.'
$lines+=''
$lines+='## Environment scope (secrets omitted)'
$lines+="- Deployment: $($profile.deployment.mode) / $($profile.deployment.host)"
$lines+="- PLM local path: $($profile.deployment.plm_local_path)"
$lines+="- Application: $($profile.application_server.kind) $($profile.application_server.version) / $($profile.application_server.host)"
$lines+="- Web: $($profile.web.url) / login=$($profile.web.login_mode)"
$lines+="- Accessible source path: $($profile.source.access_path)"
$lines+=''
$lines+='## Knowledge index (discovery only; applicability is decided below)'
$indexPath=Join-Path $w.Path 'knowledge/_index.md'
$lines+=$(if(Test-Path -LiteralPath $indexPath){Read-Utf8Text $indexPath}else{'(missing knowledge/_index.md)'})
$lines+=''
$lines+='## Applicable Verified constraints'
if (!$applicable.Count) { $lines+='(none)' }
foreach($record in $applicable) { $lines+="`n### $($record.id) [$($record.category)]`nSource: $($record.path)`n$($record.content)" }
$lines+=''
$lines+='## Candidate or fingerprint-unconfirmed knowledge'
if (!$candidate.Count -and !$conditional.Count) { $lines+='(none)' }
foreach($record in @($candidate)+@($conditional)) { $lines+="`n### $($record.id) [$($record.status); verification required]`nSource: $($record.path)`n$($record.content)" }
$lines+=''
$lines+='## Related contradictions'
if (!$contradictionPaths.Count) { $lines+='(none)' }
foreach($relative in $contradictionPaths) {
    $path=Join-Path $w.Path $relative
    if (Test-Path -LiteralPath $path -PathType Leaf) { $lines+="`n### $relative`n$(Read-Utf8Text $path)" }
}
$lines+=''
$lines+='## Excluded records'
$lines+=$(if($skipped.Count){(@($skipped | ForEach-Object {"- $($_.id) [$($_.category)]: applicability or source fingerprint mismatch"}) -join "`n")}else{'(none)'})
if ($deprecated.Count) { $lines+=(@($deprecated | ForEach-Object {"- $($_.id) [$($_.category)]: Deprecated"}) -join "`n") }

Write-Output ($lines -join "`n")
