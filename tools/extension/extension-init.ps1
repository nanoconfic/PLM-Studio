param(
    [Parameter(Mandatory=$true)][string]$Title,
    [string]$Profile,
    [switch]$CreateProfile,
    [string]$CopyEnvironmentFrom,
    [string]$ProfileConfigPath,
    [string]$ProfileLabel,
    [string]$ProductName,
    [string]$ProductVersion,
    [ValidateSet('virtual-machine','local','remote-server')][string]$DeploymentMode,
    [string]$DeploymentHost,
    [string]$PlmLocalPath,
    [string]$SourceAccessPath,
    [string]$WebUrl,
    [string]$ApplicationServerKind,
    [string]$ApplicationServerVersion,
    [ValidateSet('yes','no')][string]$DatabaseRequired,
    [string]$DatabaseVersion,
    [string]$DatabaseHost,
    [string]$DatabaseName,
    [string]$OsName,
    [string]$OsVersion,
    [switch]$ProfileSetupConfirmed,
    [switch]$NonInteractive,
    [ValidateSet('prototype','integration','linked')][string]$CapabilityMode,
    [ValidateSet('static','static-demo','embedded-static','backend')][string]$Mode,
    [ValidateSet('none','user-provided','generated','pending')][string]$DemoData,
    [string]$Module,[string]$Menu,[string]$Page,
    [string[]]$NavigationPath,[string[]]$MountSequence
)
. "$PSScriptRoot/../../tools/config/Common.ps1"
$script:EnvironmentSourceExtension=$null

function Read-RequiredValue([string]$Prompt,[string]$Current) {
    if (![string]::IsNullOrWhiteSpace($Current)) { return $Current }
    if ($NonInteractive) { throw "Missing required value: $Prompt" }
    do { $value=Read-Host $Prompt } while ([string]::IsNullOrWhiteSpace($value))
    $value.Trim()
}

function Read-OptionalValue([string]$Prompt,[string]$Default=$null) {
    $display=$(if ([string]::IsNullOrWhiteSpace($Default)) {$Prompt} else {"$Prompt [$Default]"})
    $value=Read-Host $display
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    $value.Trim()
}

function New-FreshProfileConfig {
    if (!$NonInteractive) {
        Write-Host '请一次性准备环境信息：部署模式、主机地址、PLM 软件本地文件路径、Web 地址、应用服务器和数据库信息。未知的可选项可留空。'
    }
    $resolvedMode=Read-RequiredValue '部署模式（virtual-machine/local/remote-server）' $DeploymentMode
    if ($resolvedMode -notin @('virtual-machine','local','remote-server')) { throw "Invalid deployment mode: $resolvedMode" }
    $resolvedHost=$(if ($resolvedMode -eq 'local') {'localhost'} else {Read-RequiredValue '主机地址' $DeploymentHost})
    $resolvedPlmLocalPath=$(if (![string]::IsNullOrWhiteSpace($PlmLocalPath)) {$PlmLocalPath} elseif ($NonInteractive) {$null} else {Read-OptionalValue 'PLM 软件本地文件路径' $null})
    $resolvedWebUrl=$(if (![string]::IsNullOrWhiteSpace($WebUrl)) {$WebUrl} elseif ($NonInteractive) {$null} else {Read-OptionalValue 'Web 访问地址' $null})
    $resolvedAppKind=$(if (![string]::IsNullOrWhiteSpace($ApplicationServerKind)) {$ApplicationServerKind} else {'IIS'})
    $resolvedAppVersion=$(if (![string]::IsNullOrWhiteSpace($ApplicationServerVersion)) {$ApplicationServerVersion} else {'unknown'})
    $resolvedOsName=$(if (![string]::IsNullOrWhiteSpace($OsName)) {$OsName} else {'Windows Server'})
    $resolvedOsVersion=$(if (![string]::IsNullOrWhiteSpace($OsVersion)) {$OsVersion} else {'unknown'})
    $databaseChoice=$(if (![string]::IsNullOrWhiteSpace($DatabaseRequired)) {$DatabaseRequired} elseif ($NonInteractive) {'no'} else {Read-OptionalValue '是否需要数据库（yes/no）' 'no'})
    $usesDatabase=$databaseChoice -match '^(?i:y|yes)$'
    $database=[ordered]@{required=$usesDatabase;version=$null;host=$null;name=$null;secret_ref=$null;username=$null;password=$null}
    if ($usesDatabase) {
        $database.version=Read-RequiredValue '数据库版本/产品（例如 SQL Server 2019、Oracle 11g）' $DatabaseVersion
        $database.host=Read-RequiredValue '数据库地址' $DatabaseHost
        $database.name=Read-RequiredValue '数据库名称' $DatabaseName
    }
    $accessPath=$(if (![string]::IsNullOrWhiteSpace($SourceAccessPath)) {$SourceAccessPath} elseif ($resolvedMode -eq 'local') {$resolvedPlmLocalPath} else {$null})
    $candidatePaths=@()
    if (![string]::IsNullOrWhiteSpace($accessPath)) { $candidatePaths=@($accessPath) }
    [ordered]@{
        label=$null
        product=[ordered]@{name=$null;version=$null}
        deployment=[ordered]@{mode=$resolvedMode;host=$resolvedHost;plm_local_path=$resolvedPlmLocalPath;service_name=$null;secret_ref=$null}
        os=[ordered]@{name=$resolvedOsName;version=$resolvedOsVersion;username=$null;password=$null}
        database=$database
        application_server=[ordered]@{kind=$resolvedAppKind;version=$resolvedAppVersion;host=$resolvedHost;username=$null;password=$null}
        web=[ordered]@{url=$resolvedWebUrl;login_mode='manual';secret_ref=$null;username=$null;password=$null;token=$null}
        browser=[ordered]@{enabled=$true;driver='playwright';mode='launch';cdp_endpoint=$null;storage_state_ref=$null;executable_path='tools/browser/chromium/chrome-win64/chrome.exe'}
        source=[ordered]@{auto_discover=$true;candidate_paths=$candidatePaths;access_path=$accessPath;discovery_depth=2;exclude=@('logs','log','cache','tmp','temp','node_modules','target','bin','obj','.git');exclude_files=@('.env','.env.*','*.pfx','*.key','*.pem');review_sensitive_configs=$true;secret_ref=$null;username=$null;password=$null;domain=$null}
        capabilities=[ordered]@{frontend=$true;backend=$usesDatabase;backend_decision='pending user confirmation'}
        commands=[ordered]@{build='not-applicable';run='not-applicable';test='not-applicable'}
        secret_refs=[ordered]@{}
    }
}

function Get-ExtensionEnvironmentSources($W) {
    $items=@()
    $extensionRoot=Join-Path $W.Path 'extensions'
    if (!(Test-Path -LiteralPath $extensionRoot)) { return @() }
    foreach($dir in Get-ChildItem -LiteralPath $extensionRoot -Directory | Sort-Object Name) {
        $configPath=Join-Path $dir.FullName 'extension.yaml'
        if (!(Test-Path -LiteralPath $configPath)) { continue }
        try {
            $state=Get-ExtensionGuideState $W (Read-Config $configPath)
            if ($state.lifecycle -eq 'Active' -and $state.profile -in @(Get-ConfiguredProfileNames $W)) {
                $items+=@($state)
            }
        } catch { }
    }
    @($items)
}

function Add-WorkspaceProfile($W,[string]$ProfileId) {
    if ($ProfileId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'Invalid profile ID.' }
    if ($W.Config.profiles.PSObject.Properties[$ProfileId]) { throw "Profile already exists: $ProfileId" }
    if ($CopyEnvironmentFrom -and $ProfileConfigPath) { throw 'Use either -CopyEnvironmentFrom or -ProfileConfigPath, not both.' }

    $resolvedLabel=$ProfileLabel
    if ([string]::IsNullOrWhiteSpace($resolvedLabel) -and !$NonInteractive) {
        $resolvedLabel=Read-RequiredValue '环境名称' $null
    }
    $resolvedProductName=Read-RequiredValue '产品名称' $ProductName
    $resolvedProductVersion=Read-RequiredValue '产品版本' $ProductVersion
    if ([string]::IsNullOrWhiteSpace($resolvedLabel)) { $resolvedLabel="$resolvedProductName $resolvedProductVersion $ProfileId" }

    if (!$CopyEnvironmentFrom -and !$ProfileConfigPath -and !$NonInteractive) {
        $availableExtensions=@(Get-ExtensionEnvironmentSources $W)
        if ($availableExtensions.Count) {
            Write-Host '选择环境信息来源：'
            for($i=0;$i -lt $availableExtensions.Count;$i++) {
                $item=$availableExtensions[$i]
                Write-Host ("{0}) {1}: {2} | 环境 {3}（{4}） | {5} | {6}" -f ($i+1),$item.id,$item.title,$item.profile,$item.profile_label,$item.product,$item.deployment_mode)
            }
            Write-Host 'N) 逐项录入新环境'
            $environmentChoice=Read-Host '输入序号、扩展 ID 或 N'
            if ($environmentChoice -notmatch '^(?i:n|new)$') {
                $selected=$null
                if ($environmentChoice -match '^\d+$') {
                    $index=[int]$environmentChoice-1
                    if ($index -lt 0 -or $index -ge $availableExtensions.Count) { throw "Invalid extension selection: $environmentChoice" }
                    $selected=$availableExtensions[$index]
                } else {
                    $selected=@($availableExtensions | Where-Object { $_.id -eq $environmentChoice })[0]
                    if (!$selected) { throw "Active extension not found: $environmentChoice" }
                }
                $script:CopyEnvironmentFrom=$selected.profile
                $script:EnvironmentSourceExtension=$selected.id
            }
        }
    }

    if ($CopyEnvironmentFrom) {
        $sourceProfile=Get-Profile $W $CopyEnvironmentFrom
        $profileConfig=$sourceProfile | ConvertTo-Json -Depth 40 | ConvertFrom-Json
    } elseif ($ProfileConfigPath) {
        if (!(Test-Path -LiteralPath $ProfileConfigPath -PathType Leaf)) { throw "Profile config file not found: $ProfileConfigPath" }
        $profileConfig=Read-Config $ProfileConfigPath
    } else {
        $profileConfig=New-FreshProfileConfig
    }

    foreach($obsolete in @('project','prototype_defaults')) {
        if ($profileConfig.PSObject.Properties[$obsolete]) { $profileConfig.PSObject.Properties.Remove($obsolete) }
    }
    if ($profileConfig.database -and $profileConfig.database.PSObject.Properties['engine']) {
        $legacyEngine=[string]$profileConfig.database.engine
        if (![string]::IsNullOrWhiteSpace($legacyEngine) -and ([string]$profileConfig.database.version) -notlike "*$legacyEngine*") {
            $databaseParts=@($legacyEngine,[string]$profileConfig.database.version) | Where-Object {![string]::IsNullOrWhiteSpace([string]$_)}
            $profileConfig.database.version=($databaseParts -join ' ').Trim()
        }
        $profileConfig.database.PSObject.Properties.Remove('engine')
    }
    if ($profileConfig.source -and $profileConfig.source.PSObject.Properties['selected_path']) {
        if (!$profileConfig.source.PSObject.Properties['access_path']) { $profileConfig.source | Add-Member -NotePropertyName access_path -NotePropertyValue $profileConfig.source.selected_path }
        $profileConfig.source.PSObject.Properties.Remove('selected_path')
    }
    if (!$profileConfig.deployment) { $profileConfig | Add-Member -NotePropertyName deployment -NotePropertyValue ([ordered]@{}) }
    if (!$profileConfig.deployment.PSObject.Properties['mode']) { $profileConfig.deployment | Add-Member -NotePropertyName mode -NotePropertyValue (Read-RequiredValue '部署模式（virtual-machine/local/remote-server）' $DeploymentMode) }
    if (!$profileConfig.deployment.PSObject.Properties['host']) { $profileConfig.deployment | Add-Member -NotePropertyName host -NotePropertyValue $(if ($profileConfig.deployment.mode -eq 'local') {'localhost'} else {$profileConfig.application_server.host}) }
    if (!$profileConfig.deployment.PSObject.Properties['plm_local_path']) { $profileConfig.deployment | Add-Member -NotePropertyName plm_local_path -NotePropertyValue $PlmLocalPath }
    if (![string]::IsNullOrWhiteSpace($SourceAccessPath)) {
        if (!$profileConfig.source.PSObject.Properties['access_path']) { $profileConfig.source | Add-Member -NotePropertyName access_path -NotePropertyValue $SourceAccessPath }
        else { $profileConfig.source.access_path=$SourceAccessPath }
        $profileConfig.source.candidate_paths=@($SourceAccessPath)
    }
    if ($profileConfig.deployment.PSObject.Properties['vm_workdir']) { $profileConfig.deployment.PSObject.Properties.Remove('vm_workdir') }

    $profileConfig.label=$resolvedLabel
    $profileConfig.product.name=$resolvedProductName
    $profileConfig.product.version=$resolvedProductVersion

    $environmentSource=$(if ($CopyEnvironmentFrom -and $EnvironmentSourceExtension) {"复用扩展 $EnvironmentSourceExtension 绑定的环境 $CopyEnvironmentFrom"} elseif ($CopyEnvironmentFrom) {"复用环境 $CopyEnvironmentFrom"} elseif ($ProfileConfigPath) {"导入 $ProfileConfigPath"} else {'新环境'})
    if ($NonInteractive) {
        if (!$ProfileSetupConfirmed) { throw 'New profile data must be confirmed through the interactive user flow before automation. Pass -ProfileSetupConfirmed only after confirmation.' }
    } else {
        Write-Host ''
        Write-Host '请确认新 profile：'
        Write-Host "- ID/名称：$ProfileId / $resolvedLabel"
        Write-Host "- 产品：$resolvedProductName $resolvedProductVersion"
        Write-Host "- 环境来源：$environmentSource"
        Write-Host "- 部署：$($profileConfig.deployment.mode) / $($profileConfig.deployment.host)"
        Write-Host "- PLM 软件本地文件路径：$($profileConfig.deployment.plm_local_path)"
        Write-Host "- 应用服务器：$($profileConfig.application_server.kind) / $($profileConfig.application_server.host)"
        Write-Host "- Web：$($profileConfig.web.url)"
        Write-Host "- 数据库：$(if($profileConfig.database.required){$profileConfig.database.version+' / '+$profileConfig.database.host+' / '+$profileConfig.database.name}else{'不使用'})"
        $confirmation=Read-Host '确认写入本地环境配置并创建扩展？（y/N）'
        if ($confirmation -notmatch '^(?i:y|yes)$') { throw 'Profile creation cancelled. No profile or extension was created.' }
    }

    $W.Config.profiles | Add-Member -NotePropertyName $ProfileId -NotePropertyValue $profileConfig
    Write-WorkspaceConfig $W $W.Config
    Write-Output "Profile created: $ProfileId"
}

function Select-Profile($W) {
    $availableExtensions=@(Get-ExtensionEnvironmentSources $W)
    Write-Host '请选择扩展使用的环境来源：'
    for($i=0;$i -lt $availableExtensions.Count;$i++) {
        $item=$availableExtensions[$i]
        Write-Host ("{0}) {1}: {2} | 环境 {3}（{4}） | {5} | {6}" -f ($i+1),$item.id,$item.title,$item.profile,$item.profile_label,$item.product,$item.deployment_mode)
    }
    Write-Host 'N) 新增环境'
    $choice=Read-Host '输入序号、扩展 ID 或 N'
    if ($choice -match '^(?i:n|new)$') {
        $script:CreateProfile=$true
        $newId=Read-RequiredValue '新环境 ID（字母、数字、点、下划线或短横线）' $null
        return $newId
    }
    if ($choice -match '^\d+$') {
        $index=[int]$choice-1
        if ($index -lt 0 -or $index -ge $availableExtensions.Count) { throw "Invalid extension selection: $choice" }
        return $availableExtensions[$index].profile
    }
    $selected=@($availableExtensions | Where-Object { $_.id -eq $choice })[0]
    if ($selected) { return $selected.profile }
    throw "Active extension not found: $choice"
}

$w=Get-Workspace
if ($CapabilityMode -eq 'prototype' -and $Mode -notin @('static','static-demo','backend')) { throw 'Prototype-only capability requires -Mode static, static-demo or backend.' }
if ($CapabilityMode -in @('integration','linked') -and $Mode -notin @('embedded-static','backend')) { throw 'Integration and linked capabilities require -Mode embedded-static or backend.' }
if ([string]::IsNullOrWhiteSpace($Profile)) {
    if ($NonInteractive) { throw 'Profile selection is required before creating an extension. Pass -Profile <id>, or use -CreateProfile with profile details.' }
    $Profile=Select-Profile $w
}

if ($CreateProfile) {
    Add-WorkspaceProfile $w $Profile
    $w=Get-Workspace
} else {
    $profileConfig=Get-Profile $w $Profile
    if ($Profile -notin @(Get-ConfiguredProfileNames $w)) {
        throw "Profile is incomplete and cannot be bound to a new extension: $Profile"
    }
}
$profileConfig=Get-Profile $w $Profile

# No extension directory is created until profile selection and validation succeed.
$extensions=Join-Path $w.Path 'extensions'
New-Item -ItemType Directory -Force -Path $extensions | Out-Null
$lock=[IO.File]::Open((Join-Path $extensions '.allocation.lock'),'OpenOrCreate','ReadWrite','None')
try {
    $max=0
    Get-ChildItem -LiteralPath $extensions -Directory | ForEach-Object { if ($_.Name -match '^EXT-(\d+)$') { $max=[Math]::Max($max,[int]$Matches[1]) } }
    $id='EXT-{0:D3}' -f ($max+1)
    $dest=Join-Path $extensions $id
    New-Item -ItemType Directory -Path $dest | Out-Null
    try {
        Copy-Item -LiteralPath "$script:StudioRoot/templates/extension/extension.yaml" -Destination (Join-Path $dest 'extension.yaml')
        Copy-Item -LiteralPath "$script:StudioRoot/templates/extension/brief.md" -Destination (Join-Path $dest 'brief.md')
        $c=Read-Config (Join-Path $dest 'extension.yaml')
        $c.id=$id; $c.title=$Title; $c.workspace_id=$w.Id; $c.profile=$Profile; $c.created_at=(Get-Date).ToUniversalTime().ToString('o')
        $c.target.module=$Module; $c.target.menu=$Menu; $c.target.page=$Page
        if ($NavigationPath) { $c.target.navigation_path=@($NavigationPath) }
        elseif ($Menu) { $c.target.navigation_path=@(ConvertTo-NavigationPathParts $Menu) }
        if ($MountSequence) { $c.target.mount_sequence=@($MountSequence) }
        if ($Mode) { $c.delivery.mode=$Mode }
        if ($DemoData) { $c.delivery.demo_data=$DemoData }
        elseif ($Mode -eq 'static') { $c.delivery.demo_data='none' }
        if ($Mode -eq 'backend') { $c.delivery.backend='pending' } else { $c.delivery.backend='no' }
        $c.workflow.delivery_confirmed=($Mode -in @('static','static-demo','embedded-static','backend'))
        if ($CapabilityMode) { $c.workflow.capability_mode=$CapabilityMode }
        $c.workflow.stage=$(if ($CapabilityMode -eq 'integration') {'integration'} else {'prototype'})
        $c.workflow.prototype_accepted=$false
        $c.workflow.phase='Requirements'
        $c.workflow.requirements_confirmed=$false
        $c.workflow.next_action=$(if ($CapabilityMode -eq 'integration') {'Collect and confirm integration requirements; do not modify the original system yet'} else {'Collect and confirm prototype design requirements; do not implement yet'})
        $c.original_system_change.applies_to_extension=$id
        Write-Config (Join-Path $dest 'extension.yaml') $c
        Write-Output $dest
        $issues=@(Get-Issues $w $c)
        if ($issues.Count) { Write-Output 'Pending confirmation:'; $issues | Write-Output }
        Write-Output 'Delivery mode is recorded. STOP before design or implementation.'
        if ($CapabilityMode -eq 'integration') {
            Write-Output 'Next: identify the HTML artifact, PLM click path and mount sequence, entry behavior, environment, snapshot and acceptance criteria.'
            Write-Output 'After integration requirements are confirmed, run integration-preflight.'
        } else {
            Write-Output 'Next: ask for prototype goal, scenario, data source, backend decision, style path, UI, acceptance criteria and constraints.'
            Write-Output 'After prototype requirements are confirmed, run prototype-preflight.'
        }
        Write-Output 'Loading applicable knowledge for discovery only; this does not authorize design before requirements confirmation.'
        & "$script:StudioRoot/skills/knowledge-context/run.ps1" -Extension $id -Facet Auto
    } catch {
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        throw
    }
} finally { $lock.Dispose() }
