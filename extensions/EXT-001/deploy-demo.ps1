param(
    [string]$Root = "\\192.168.40.76\1_Server"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $workspaceRoot 'scripts/Common.ps1')
$manifest = Read-Config (Join-Path $workspaceRoot 'vendor/source-manifest-DEV.yaml')
$expected = @{}
foreach ($file in $manifest.files) { $expected[$file.path.Replace('\', '/')] = $file.sha256 }

$originals = @(
    'InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.menu',
    'InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.dic',
    'InforCenter/PSE/Bom/Config/PSEBomFileRef.fileref'
)
$newFiles = @(
    'InforCenter/PSE/Bom/Js/TrialToMassProductionDemo.js',
    'InforCenter/PSE/Bom/Config/Pages/TrialToMassProductionDemo.page',
    'InforCenter/PSE/Bom/Config/Pages/TrialToMassProductionDemo.dic'
)

function Get-RemotePath([string]$RelativePath) {
    Join-Path $Root ($RelativePath.Replace('/', '\'))
}
function Get-Utf8Text([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $offset = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $offset = 3 }
    $encoding = New-Object System.Text.UTF8Encoding($false, $true)
    return $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
}
function Write-Utf8PreservingBom([string]$Path, [string]$Text) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $encoding = New-Object System.Text.UTF8Encoding($false, $true)
    $body = $encoding.GetBytes($Text)
    if ($hasBom) {
        $output = New-Object byte[] ($body.Length + 3)
        $output[0] = 0xEF; $output[1] = 0xBB; $output[2] = 0xBF
        [Array]::Copy($body, 0, $output, 3, $body.Length)
        [IO.File]::WriteAllBytes($Path, $output)
    } else {
        [IO.File]::WriteAllBytes($Path, $body)
    }
}

# Preflight: source must remain exactly at the reviewed DEV manifest state.
foreach ($relative in $originals) {
    $target = Get-RemotePath $relative
    if (!(Test-Path -LiteralPath $target)) { throw "Missing original target: $target" }
    $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($hash -ne $expected[$relative]) { throw "Remote source changed after review: $relative" }
}
foreach ($relative in $newFiles) {
    $target = Get-RemotePath $relative
    if (Test-Path -LiteralPath $target) { throw "New target already exists; refusing to overwrite: $target" }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $PSScriptRoot "deployment-backup/$stamp"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
foreach ($relative in $originals) {
    $source = Get-RemotePath $relative
    $backup = Join-Path $backupRoot ($relative.Replace('/', '\'))
    New-Item -ItemType Directory -Force -Path (Split-Path $backup -Parent) | Out-Null
    Copy-Item -LiteralPath $source -Destination $backup
}

$menuPath = Get-RemotePath 'InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.menu'
$dicPath = Get-RemotePath 'InforCenter/PSE/Bom/Config/MenuItem/PseBomMenu.dic'
$fileRefPath = Get-RemotePath 'InforCenter/PSE/Bom/Config/PSEBomFileRef.fileref'
$newAction = @'
    <WebAction Name="TrialToMassProductionDemo" MultiMenu="false" ModuleName="PSE" LabelName="PseBomMenu.TrialToMassProductionDemo" Image="s_common_operations" ParentWebAtionName="BOMCommon" RefreshType="" RefreshedSelect="false" RefreshedHiddentObjectInspectorPage="false" DropDownItemIsHideCustom="false" IsHidden="false" IsTemplate="false" Order="2600" IsMainConfig="false">
      <ActionChecker SelectID="[TreeList_Current_MASTERID$]" SelectMode="SINGLE" Action="" ActionType="PSEITEM" SelectType="[{&quot;ObjectType&quot;:&quot;PSEITEM&quot;,&quot;InfoList&quot;:[]},{&quot;ObjectType&quot;:&quot;PSEITEM$&quot;,&quot;InfoList&quot;:[]}]" />
      <JSMethod Name="InforCenter_Custom_TrialToMassProduction_OpenDemo" SelectID="[TreeList_Current_MASTERID$]" IsLoopExec="false">
        <Para Name="ItemCode" Value="[TreeList_Current_ECODE]" />
        <Para Name="ItemName" Value="[TreeList_Current_ENAME]" />
        <Para Name="ItemMasterID" Value="[TreeList_Current_MASTERID$]" />
        <Para Name="ViewID" Value="[TreeList_Current_PSEITEMVIEWEID]" />
        <Para Name="ViewType" Value="[TreeList_Current_PSEITEMVIEWVIEWTYPE]" />
        <Para Name="TreeListID" Value="[TREELISTID]" />
      </JSMethod>
    </WebAction>
'@
$newLabels = @'
    <Label Name="TrialToMassProductionDemo">
      <LocalizedLabel LanguageRef="zhs">&#x8BD5;&#x5236;&#x8F6C;&#x91CF;&#x4EA7;</LocalizedLabel>
      <LocalizedLabel LanguageRef="en">Trial to Mass Production</LocalizedLabel>
    </Label>
    <Label Name="TrialToMassProductionOnlyModel">
      <LocalizedLabel LanguageRef="zhs">&#x4EC5;&#x53EF;&#x5BF9;&#x8F66;&#x578B;&#x8FDB;&#x884C;&#x8F6C;&#x91CF;&#x4EA7;&#xFF01;&#xFF01;</LocalizedLabel>
      <LocalizedLabel LanguageRef="en">Only model-level items can be converted to mass production.</LocalizedLabel>
    </Label>
'@

$created = @()
try {
    $menu = Get-Utf8Text $menuPath
    $menuMarker = '    <WebAction Name="Refesh" MultiMenu="false" ModuleName="PSE"'
    if ($menu.IndexOf($menuMarker) -lt 0 -or $menu.Contains('Name="TrialToMassProductionDemo"')) { throw 'Unexpected PseBomMenu.menu content.' }
    Write-Utf8PreservingBom $menuPath ($menu.Replace($menuMarker, $newAction + $menuMarker))

    $dic = Get-Utf8Text $dicPath
    $dicPattern = '(?s)(\s*</Context>\s*</DictionarySerializer>\s*)$'
    if (-not [regex]::IsMatch($dic, $dicPattern) -or $dic.Contains('Name="TrialToMassProductionDemo"')) { throw 'Unexpected PseBomMenu.dic content.' }
    $dicReplacement = "`r`n" + $newLabels + "  </Context>`r`n</DictionarySerializer>`r`n"
    Write-Utf8PreservingBom $dicPath ([regex]::Replace($dic, $dicPattern, $dicReplacement))

    $fileRef = Get-Utf8Text $fileRefPath
    $refMarker = '  <JSFile FileName ="~/InforCenter/PSE/Bom/Js/OperateInBom.js" group="InforCenter"/>'
    $newRef = $refMarker + "`r`n" + '  <JSFile FileName ="~/InforCenter/PSE/Bom/Js/TrialToMassProductionDemo.js" group="InforCenter"/>'
    if ($fileRef.IndexOf($refMarker) -lt 0 -or $fileRef.Contains('TrialToMassProductionDemo.js')) { throw 'Unexpected PSEBomFileRef.fileref content.' }
    Write-Utf8PreservingBom $fileRefPath ($fileRef.Replace($refMarker, $newRef))

    foreach ($relative in $newFiles) {
        $source = Join-Path $PSScriptRoot "deployment-package/$($relative.Replace('/', '\'))"
        $target = Get-RemotePath $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
        $created += $target
    }

    # Validate deployed XML and copied file hashes.
    [xml](Get-Utf8Text $menuPath) | Out-Null
    [xml](Get-Utf8Text $dicPath) | Out-Null
    [xml](Get-Utf8Text $fileRefPath) | Out-Null
    [xml](Get-Utf8Text (Get-RemotePath 'InforCenter/PSE/Bom/Config/Pages/TrialToMassProductionDemo.page')) | Out-Null
    [xml](Get-Utf8Text (Get-RemotePath 'InforCenter/PSE/Bom/Config/Pages/TrialToMassProductionDemo.dic')) | Out-Null
    foreach ($relative in $newFiles) {
        $source = Join-Path $PSScriptRoot "deployment-package/$($relative.Replace('/', '\'))"
        $target = Get-RemotePath $relative
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash) { throw "Copied file verification failed: $relative" }
    }

    $record = [ordered]@{
        deployed_at = (Get-Date).ToUniversalTime().ToString('o')
        root = $Root
        source_fingerprint = $manifest.source_fingerprint
        backup = $backupRoot
        originals = @{}
        new_files = $newFiles
        service_restart = 'not performed'
    }
    foreach ($relative in $originals) { $record.originals[$relative] = (Get-FileHash -LiteralPath (Get-RemotePath $relative) -Algorithm SHA256).Hash }
    Write-Config (Join-Path $backupRoot 'deployment-record.json') $record
    Write-Output "Deployment succeeded. Backup: $backupRoot"
}
catch {
    foreach ($relative in $originals) {
        $backup = Join-Path $backupRoot ($relative.Replace('/', '\'))
        if (Test-Path -LiteralPath $backup) { Copy-Item -LiteralPath $backup -Destination (Get-RemotePath $relative) -Force }
    }
    foreach ($target in $created) { if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force } }
    throw
}
