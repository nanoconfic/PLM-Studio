Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:StudioRoot = Split-Path $PSScriptRoot -Parent

function Read-Utf8Text($Path) {
    $utf8=[System.Text.UTF8Encoding]::new($false,$true)
    [System.IO.File]::ReadAllText($Path,$utf8)
}

function Write-Utf8Text($Path,[string]$Text) {
    $parent=Split-Path $Path -Parent
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $utf8=[System.Text.UTF8Encoding]::new($false,$true)
    [System.IO.File]::WriteAllText($Path,$Text,$utf8)
}

function Add-Utf8Text($Path,[string]$Text) {
    $current=$(if (Test-Path -LiteralPath $Path) { Read-Utf8Text $Path } else { '' })
    Write-Utf8Text $Path ($current+$Text)
}

function Read-Config($Path) {
    try {
        $text=Read-Utf8Text $Path
        $text | ConvertFrom-Json
    } catch { throw "Cannot read $Path as strict UTF-8 JSON-compatible YAML. $($_.Exception.Message)" }
}

function Write-Config($Path,$Value) {
    $json=($Value | ConvertTo-Json -Depth 40)+[Environment]::NewLine
    Write-Utf8Text $Path $json
}

function Get-Workspace {
    $path=Join-Path $script:StudioRoot 'workspace.yaml'
    if (!(Test-Path -LiteralPath $path)) { throw 'Missing workspace.yaml in the PLM-Studio workspace root.' }
    $config=Read-Config $path
    [pscustomobject]@{Id=$config.workspace_id;Path=$script:StudioRoot;Config=$config}
}

function Get-Profile($W,[string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { throw 'The extension must bind a profile.' }
    if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'Invalid profile ID.' }
    $property=$W.Config.profiles.PSObject.Properties[$Name]
    if (!$property) { throw "Profile not found in workspace.yaml: $Name" }
    $property.Value
}

function Get-ConfiguredProfileNames($W) {
    @($W.Config.profiles.PSObject.Properties | Where-Object {
        $_.Value.project.id -and $_.Value.product.name -and $_.Value.product.version
    } | ForEach-Object { $_.Name })
}

function Get-Extension($W,[string]$Id) {
    if ($Id -notmatch '^EXT-\d+$') { throw 'Extension ID must match EXT-nnn.' }
    $path=Join-Path $W.Path "extensions/$Id"
    $configPath=Join-Path $path 'extension.yaml'
    if (!(Test-Path -LiteralPath $configPath)) { throw "Missing extension: $Id" }
    [pscustomobject]@{Id=$Id;Path=$path;Config=(Read-Config $configPath)}
}

function Add-MissingProperty($Object,[string]$Name,$Value) {
    if (!$Object.PSObject.Properties[$Name]) { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function New-RequirementState {
    [ordered]@{change_goal=$null;user_scenario=$null;inputs=@();ui_and_interaction=@();acceptance_criteria=@();constraints=@();out_of_scope=@()}
}

function New-ValidationState {
    [ordered]@{status='NotReady';requested_at=$null;responded_at=$null;feedback=$null}
}

function New-KnowledgeCaptureState {
    [ordered]@{candidates=@();promoted=@()}
}

function Initialize-ExtensionWorkflow($Config) {
    Add-MissingProperty $Config 'lifecycle' ([ordered]@{status='Active';archived_at=$null;reason=$null})
    Add-MissingProperty $Config 'requirements' (New-RequirementState)
    Add-MissingProperty $Config 'validation' (New-ValidationState)
    Add-MissingProperty $Config 'knowledge_capture' (New-KnowledgeCaptureState)
    Add-MissingProperty $Config 'iteration_history' @()
    Add-MissingProperty $Config 'result' ([ordered]@{summary=$null;artifacts=@();completed_at=$null})
    if (!$Config.PSObject.Properties['workflow']) {
        $legacy=[string]$Config.status
        $accepted=$legacy -match '(?i)(DeployedUserVerified|Completed|Accepted)'
        $phase=$(if ($accepted) {'Completed'} elseif ($legacy -match '(?i)PendingUserReview') {'PendingUserReview'} elseif ($legacy -match '(?i)ChangesRequested') {'ChangesRequested'} elseif ($legacy -match '(?i)(Analyzing|Implementation)') {'Implementation'} else {'Requirements'})
        $validation=$(if ($accepted) {'Accepted'} elseif ($phase -eq 'PendingUserReview') {'PendingUserReview'} elseif ($phase -eq 'ChangesRequested') {'ChangesRequested'} else {'NotReady'})
        $Config.validation.status=$validation
        $Config | Add-Member -NotePropertyName workflow -NotePropertyValue ([ordered]@{current_iteration='ITER-001';phase=$phase;requirements_confirmed=$false;next_action=$null})
    } else {
        Add-MissingProperty $Config.workflow 'current_iteration' 'ITER-001'
        Add-MissingProperty $Config.workflow 'phase' 'Requirements'
        Add-MissingProperty $Config.workflow 'requirements_confirmed' $false
        Add-MissingProperty $Config.workflow 'next_action' $null
    }
    $Config
}

function Get-ExtensionGuideState($W,$Config) {
    $c=Initialize-ExtensionWorkflow $Config
    $profileId=[string]$c.profile
    $profileLabel='Unbound'
    $project='Unbound'
    $product='Unbound'
    try {
        $p=Get-Profile $W $profileId
        $profileLabel=$(if ($p.label) {[string]$p.label} else {$profileId})
        $project=$(if ($p.project.name) {[string]$p.project.name} else {'Unconfigured'})
        $product=$(if ($p.product.name) {[string]$p.product.name+' '+[string]$p.product.version} else {'Unconfigured'})
    } catch { }
    $lifecycle=[string]$c.lifecycle.status
    $phase=[string]$c.workflow.phase
    $validation=[string]$c.validation.status
    $action='ContinueImplementation'
    if ($lifecycle -eq 'Archived') { $action='Archived' }
    elseif ($validation -eq 'Accepted' -or $phase -eq 'Completed') { $action='StartNewIteration' }
    elseif ($validation -eq 'PendingUserReview' -or $phase -eq 'PendingUserReview') { $action='AwaitUserReview' }
    elseif ($validation -eq 'ChangesRequested' -or $phase -eq 'ChangesRequested') { $action='ApplyFeedback' }
    elseif ($phase -in @('Draft','Requirements') -or !$c.requirements.change_goal -or @($c.requirements.acceptance_criteria).Count -eq 0) { $action='CollectRequirements' }
    [pscustomobject]@{
        id=[string]$c.id;title=[string]$c.title;profile=$profileId;profile_label=$profileLabel;project=$project;product=$product
        lifecycle=$lifecycle;iteration=[string]$c.workflow.current_iteration;phase=$phase;validation=$validation;next_action=$action
    }
}

function Get-Issues($W,$ExtensionConfig=$null) {
    $c=$W.Config
    if ([string]::IsNullOrWhiteSpace([string]$c.workspace_id)) { 'Missing: workspace_id' }
    if (@(Get-ConfiguredProfileNames $W).Count -eq 0) { 'No configured profiles. Add project, product and version under workspace.yaml.profiles.<id>.' }
    if (!$ExtensionConfig) { return }

    $e=$ExtensionConfig
    if ([string]::IsNullOrWhiteSpace([string]$e.profile)) { 'Extension is not bound to a profile.'; return }
    try { $p=Get-Profile $W $e.profile } catch { $_.Exception.Message; return }
    foreach($key in @('project.id','project.name','product.name','product.version')) {
        $parts=$key.Split('.'); $value=$p.($parts[0]).($parts[1]); if ([string]::IsNullOrWhiteSpace([string]$value)) { "Missing in profile $($e.profile): $key" }
    }
    if (!$p.prototype_defaults) { "Missing in profile $($e.profile): prototype_defaults" }
    $mode=[string]$e.delivery.mode
    if ($mode -notin @('static','static-demo','embedded-static','backend')) { 'Missing/invalid: delivery.mode (static/static-demo/embedded-static/backend)'; return }
    if ($e.workspace_id -ne $c.workspace_id) { 'extension.workspace_id does not match workspace.yaml.' }
    if ($mode -eq 'static-demo' -and $e.delivery.demo_data -notin @('user-provided','generated')) { 'static-demo requires delivery.demo_data user-provided or generated.' }
    if ($mode -in @('embedded-static','backend')) {
        if (!$e.target.module -and !$e.target.menu -and !$e.target.page) { 'Embedded/backend delivery requires a target module, menu or page.' }
        foreach($key in @('os.name','os.version','application_server.kind','application_server.host','web.url','web.login_mode','source.selected_path')) {
            $parts=$key.Split('.'); $value=$p.($parts[0]).($parts[1]); if ([string]::IsNullOrWhiteSpace([string]$value)) { "Missing for ${mode}: $key" }
        }
        if ($p.source.selected_path -and !(Test-Path -LiteralPath $p.source.selected_path)) { 'source.selected_path is unavailable.' }
    }
    if ($mode -eq 'backend') {
        if ($e.delivery.backend -ne 'approved') { 'backend delivery requires delivery.backend=approved.' }
        if ($p.database.required -ne $true) { 'backend delivery requires database.required=true.' }
        foreach($key in @('engine','version','host','name')) { if (!$p.database.$key) { "Missing for backend: database.$key" } }
    }
}

function New-Snapshot($W,[string]$ProfileName) {
    $profile=Get-Profile $W $ProfileName
    $id=(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6)
    $path=Join-Path $W.Path "knowledge/environment-snapshots/$id.yaml"
    Write-Config $path ([ordered]@{captured_at=(Get-Date).ToUniversalTime().ToString('o');workspace_id=$W.Id;profile_id=$ProfileName;profile=$profile})
    $path
}

function Assert-Child($Parent,$Child) {
    $a=[IO.Path]::GetFullPath($Parent).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    $b=[IO.Path]::GetFullPath($Child)
    if (!$b.StartsWith($a,[StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe target: $b" }
}
