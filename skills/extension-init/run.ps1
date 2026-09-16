param(
    [Parameter(Mandatory=$true)][string]$Title,
    [string]$Profile,
    [switch]$CreateProfile,
    [string]$CopyEnvironmentFrom,
    [string]$ProfileConfigPath,
    [string]$ProfileLabel,
    [string]$ProjectId,
    [string]$ProjectName,
    [string]$ProductName,
    [string]$ProductVersion,
    [switch]$ProfileSetupConfirmed,
    [switch]$NonInteractive,
    [ValidateSet('static','static-demo','embedded-static','backend')][string]$Mode,
    [ValidateSet('none','user-provided','generated','pending')][string]$DemoData,
    [string]$Module,[string]$Menu,[string]$Page
)
. "$PSScriptRoot/../../scripts/Common.ps1"

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
    if ($NonInteractive) {
        throw 'Creating a new environment non-interactively requires -CopyEnvironmentFrom <profile> or -ProfileConfigPath <file>.'
    }
    Write-Host '请输入新 profile 的核心环境信息；未知项可输入 unknown，不适用项可输入 not-applicable。'
    $osName=Read-OptionalValue '操作系统名称' 'Windows Server'
    $osVersion=Read-OptionalValue '操作系统版本' 'unknown'
    $appKind=Read-OptionalValue '应用服务器类型' 'IIS'
    $appVersion=Read-OptionalValue '应用服务器版本' 'unknown'
    $appHost=Read-OptionalValue '应用服务器地址' 'unknown'
    $webUrl=Read-OptionalValue 'Web 访问地址' $null
    $loginMode=Read-OptionalValue '登录方式' 'manual'
    $sourcePath=Read-OptionalValue '原系统源文件路径' $null
    $databaseAnswer=(Read-OptionalValue '是否需要数据库（y/N）' 'N')
    $databaseRequired=$databaseAnswer -match '^(?i:y|yes)$'
    $database=[ordered]@{required=$databaseRequired;engine=$null;version=$null;host=$null;name=$null;secret_ref=$null;username=$null;password=$null}
    if ($databaseRequired) {
        $database.engine=Read-OptionalValue '数据库类型' 'sqlserver'
        $database.version=Read-OptionalValue '数据库版本' 'unknown'
        $database.host=Read-RequiredValue '数据库地址' $null
        $database.name=Read-RequiredValue '数据库名称' $null
    }
    $candidatePaths=@()
    if (![string]::IsNullOrWhiteSpace($sourcePath)) { $candidatePaths=@($sourcePath) }
    [ordered]@{
        label=$null
        project=[ordered]@{id=$null;name=$null}
        product=[ordered]@{name=$null;version=$null}
        prototype_defaults=[ordered]@{backend='ask';demo_data='ask';demo_data_source='ask';integration='ask';original_system_change='per-extension'}
        os=[ordered]@{name=$osName;version=$osVersion;username=$null;password=$null}
        database=$database
        application_server=[ordered]@{kind=$appKind;version=$appVersion;host=$appHost;username=$null;password=$null}
        web=[ordered]@{url=$webUrl;login_mode=$loginMode;secret_ref=$null;username=$null;password=$null;token=$null}
        browser=[ordered]@{enabled=$true;driver='playwright';mode='launch';cdp_endpoint=$null;storage_state_ref=$null;executable_path='tools/browser/chromium/chrome-win64/chrome.exe'}
        source=[ordered]@{auto_discover=$true;candidate_paths=$candidatePaths;selected_path=$sourcePath;discovery_depth=2;exclude=@('logs','log','cache','tmp','temp','node_modules','target','bin','obj','.git');exclude_files=@('.env','.env.*','*.pfx','*.key','*.pem');review_sensitive_configs=$true;username=$null;password=$null;domain=$null}
        capabilities=[ordered]@{frontend=$true;backend=$databaseRequired;backend_decision='pending user confirmation'}
        commands=[ordered]@{build='not-applicable';run='not-applicable';test='not-applicable'}
        secret_refs=[ordered]@{}
        deployment=[ordered]@{vm_workdir=$sourcePath;service_name=$null;username=$null;password=$null}
    }
}

function Add-WorkspaceProfile($W,[string]$ProfileId) {
    if ($ProfileId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'Invalid profile ID.' }
    if ($W.Config.profiles.PSObject.Properties[$ProfileId]) { throw "Profile already exists: $ProfileId" }
    if ($CopyEnvironmentFrom -and $ProfileConfigPath) { throw 'Use either -CopyEnvironmentFrom or -ProfileConfigPath, not both.' }

    $resolvedProjectId=Read-RequiredValue '项目 ID' $ProjectId
    $resolvedProjectName=Read-RequiredValue '项目名称' $ProjectName
    $resolvedProductName=Read-RequiredValue '产品名称' $ProductName
    $resolvedProductVersion=Read-RequiredValue '产品版本' $ProductVersion
    $resolvedLabel=$(if (![string]::IsNullOrWhiteSpace($ProfileLabel)) {$ProfileLabel} else {"$resolvedProjectName $resolvedProductName $resolvedProductVersion $ProfileId"})

    if (!$CopyEnvironmentFrom -and !$ProfileConfigPath -and !$NonInteractive) {
        $available=@(Get-ConfiguredProfileNames $W)
        if ($available.Count) {
            Write-Host ('选择环境信息来源：输入现有 profile ID 复用环境，或输入 NEW 逐项录入。现有： '+($available -join ', '))
            $environmentChoice=Read-Host '环境信息来源'
            if ($environmentChoice -notmatch '^(?i:new|n)$') { $script:CopyEnvironmentFrom=$environmentChoice }
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

    $profileConfig.label=$resolvedLabel
    $profileConfig.project.id=$resolvedProjectId
    $profileConfig.project.name=$resolvedProjectName
    $profileConfig.product.name=$resolvedProductName
    $profileConfig.product.version=$resolvedProductVersion

    $environmentSource=$(if ($CopyEnvironmentFrom) {"复用 $CopyEnvironmentFrom"} elseif ($ProfileConfigPath) {"导入 $ProfileConfigPath"} else {'新环境'})
    if ($NonInteractive) {
        if (!$ProfileSetupConfirmed) { throw 'New profile data must be confirmed through the interactive user flow before automation. Pass -ProfileSetupConfirmed only after confirmation.' }
    } else {
        Write-Host ''
        Write-Host '请确认新 profile：'
        Write-Host "- ID/名称：$ProfileId / $resolvedLabel"
        Write-Host "- 项目：$resolvedProjectId / $resolvedProjectName"
        Write-Host "- 产品：$resolvedProductName $resolvedProductVersion"
        Write-Host "- 环境来源：$environmentSource"
        Write-Host "- 应用服务器：$($profileConfig.application_server.kind) / $($profileConfig.application_server.host)"
        Write-Host "- Web：$($profileConfig.web.url)"
        Write-Host "- 源文件：$($profileConfig.source.selected_path)"
        $confirmation=Read-Host '确认写入 workspace.yaml 并创建扩展？（y/N）'
        if ($confirmation -notmatch '^(?i:y|yes)$') { throw 'Profile creation cancelled. No profile or extension was created.' }
    }

    $W.Config.profiles | Add-Member -NotePropertyName $ProfileId -NotePropertyValue $profileConfig
    Write-Config (Join-Path $W.Path 'workspace.yaml') $W.Config
    Write-Output "Profile created: $ProfileId"
}

function Select-Profile($W) {
    $available=@(Get-ConfiguredProfileNames $W)
    Write-Host '请选择扩展使用的 profile：'
    for($i=0;$i -lt $available.Count;$i++) {
        $item=Get-Profile $W $available[$i]
        Write-Host ("{0}) {1} - {2} / {3} {4}" -f ($i+1),$available[$i],$item.project.name,$item.product.name,$item.product.version)
    }
    Write-Host 'N) 新增 profile'
    $choice=Read-Host '输入序号、profile ID 或 N'
    if ($choice -match '^(?i:n|new)$') {
        $script:CreateProfile=$true
        $newId=Read-RequiredValue '新 profile ID（字母、数字、点、下划线或短横线）' $null
        return $newId
    }
    if ($choice -match '^\d+$') {
        $index=[int]$choice-1
        if ($index -lt 0 -or $index -ge $available.Count) { throw "Invalid profile selection: $choice" }
        return $available[$index]
    }
    if ($choice -in $available) { return $choice }
    throw "Profile is not configured or does not exist: $choice"
}

$w=Get-Workspace
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
        if (!$Mode) {
            $d=$profileConfig.prototype_defaults
            if ($d.backend -eq 'required') { $Mode='backend' }
            elseif ($d.integration -eq 'required') { $Mode='embedded-static' }
            elseif ($d.demo_data -eq 'required') { $Mode='static-demo' }
        }
        if ($Mode) { $c.delivery.mode=$Mode }
        if ($DemoData) { $c.delivery.demo_data=$DemoData }
        elseif ($Mode -eq 'static') { $c.delivery.demo_data='none' }
        if ($Mode -eq 'backend') { $c.delivery.backend='pending' } else { $c.delivery.backend='no' }
        $c.original_system_change.applies_to_extension=$id
        Write-Config (Join-Path $dest 'extension.yaml') $c
        Write-Output $dest
        $issues=@(Get-Issues $w $c)
        if ($issues.Count) { Write-Output 'Pending confirmation:'; $issues | Write-Output }
        Write-Output 'Next questions: goal and user scenario; inputs/data source; target module/menu/page; UI and interaction; acceptance criteria; constraints and out of scope.'
        Write-Output 'Loading applicable knowledge into the current context before design.'
        & "$script:StudioRoot/skills/knowledge-context/run.ps1" -Extension $id -Facet Auto
    } catch {
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        throw
    }
} finally { $lock.Dispose() }
