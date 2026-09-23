Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:StudioRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

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

function Merge-ConfigValue($Base,$Overlay) {
    if ($null -eq $Overlay) { return $Base }
    if ($null -eq $Base) { return $Overlay }
    $baseIsObject=($Base -is [pscustomobject])
    $overlayIsObject=($Overlay -is [pscustomobject])
    if (!$baseIsObject -or !$overlayIsObject) { return $Overlay }
    $merged=[ordered]@{}
    foreach($property in $Base.PSObject.Properties) { $merged[$property.Name]=$property.Value }
    foreach($property in $Overlay.PSObject.Properties) {
        $merged[$property.Name]=$(if ($merged.Contains($property.Name)) { Merge-ConfigValue $merged[$property.Name] $property.Value } else { $property.Value })
    }
    [pscustomobject]$merged
}

function Get-WorkspacePaths {
    [pscustomobject]@{
        Shared=(Join-Path $script:StudioRoot 'workspace.yaml')
        Local=(Join-Path $script:StudioRoot 'workspace.local.yaml')
    }
}

function Get-Workspace {
    $paths=Get-WorkspacePaths
    if (!(Test-Path -LiteralPath $paths.Shared)) { throw 'Missing workspace.yaml in the PLM-Studio workspace root.' }
    $shared=Read-Config $paths.Shared
    $local=$(if (Test-Path -LiteralPath $paths.Local) { Read-Config $paths.Local } else { $null })
    $config=Merge-ConfigValue $shared $local
    [pscustomobject]@{Id=$config.workspace_id;Path=$script:StudioRoot;Config=$config;SharedPath=$paths.Shared;LocalPath=$paths.Local}
}

function Write-WorkspaceConfig($W,$Value) {
    if (!$W.LocalPath) { throw 'Workspace local configuration path is unavailable.' }
    Write-Config $W.LocalPath $Value
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
        $_.Value.label -and $_.Value.product.name -and $_.Value.product.version -and
        $_.Value.deployment.mode -in @('virtual-machine','local','remote-server')
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
    [ordered]@{
        change_goal=$null;user_scenario=$null;inputs=@();ui_and_interaction=@();acceptance_criteria=@();constraints=@();out_of_scope=@()
        data_preview=[ordered]@{required=$false;mode='none';columns=@();interaction=@()}
    }
}

function New-IntegrationRequirementState {
    [ordered]@{
        source_artifact=$null;source_kind='pending';entry_behavior=$null
        acceptance_criteria=@();constraints=@();out_of_scope=@()
    }
}

function New-IntegrationEvidenceState {
    [ordered]@{changes=@();verification=@();rollback=$null}
}

function Get-IntegrationEvidenceIssues($W,$ExtensionConfig) {
    $c=Initialize-ExtensionWorkflow $ExtensionConfig
    $issues=@()
    $e=$c.integration_evidence
    if (@($e.changes).Count -eq 0) { $issues+='No integration file changes were recorded.' }
    if (@($e.verification).Count -eq 0) { $issues+='Missing integration verification.' }
    if (!$e.rollback) { $issues+='Missing integration rollback procedure.' }
    foreach($change in @($e.changes)) {
        $path=[string]$change.path
        if (!$path -or !(Test-Path -LiteralPath $path -PathType Leaf)) { $issues+="Changed file is missing: $path"; continue }
        $full=[IO.Path]::GetFullPath($path)
        $approved=$false
        foreach($entry in @($c.original_system_change.approved_paths)) {
            if (!$entry) { continue }
            $parent=[IO.Path]::GetFullPath([string]$entry).TrimEnd('\','/')
            if ($full.Equals($parent,[StringComparison]::OrdinalIgnoreCase) -or
                $full.StartsWith($parent+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { $approved=$true; break }
        }
        if (!$approved) { $issues+="Changed file is outside approved_paths: $path" }
        if (!(Test-Path -LiteralPath ([string]$change.backup) -PathType Leaf)) { $issues+="Backup is missing for: $path" }
        elseif ([string]$change.before_sha256 -match '^[A-Fa-f0-9]{64}$' -and
            (Get-FileHash -LiteralPath ([string]$change.backup) -Algorithm SHA256).Hash -ne [string]$change.before_sha256) {
            $issues+="Backup hash differs from before_sha256: $path"
        }
        if ([string]$change.before_sha256 -notmatch '^[A-Fa-f0-9]{64}$') { $issues+="Invalid before_sha256 for: $path" }
        if ([string]$change.after_sha256 -notmatch '^[A-Fa-f0-9]{64}$') { $issues+="Invalid after_sha256 for: $path" }
        elseif ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne [string]$change.after_sha256) { $issues+="Current file hash differs from after_sha256: $path" }
        if ([string]$change.before_sha256 -eq [string]$change.after_sha256) { $issues+="No file difference recorded for: $path" }
        if (!$change.diff) { $issues+="Missing difference summary for: $path" }
    }
    @($issues)
}

function New-ValidationState {
    [ordered]@{status='NotReady';requested_at=$null;responded_at=$null;feedback=$null}
}

function New-KnowledgeCaptureState {
    [ordered]@{candidates=@();promoted=@()}
}

function New-StyleContextState {
    [ordered]@{
        status='pending';source='pending';matched_knowledge_ids=@();user_confirmed=$false
        evidence=@();confirmed_at=$null;basis=$null
    }
}

function ConvertTo-NavigationPathParts($Value) {
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        return @($Value -split '\s*(?:→|>)\s*' | ForEach-Object {$_.Trim()} | Where-Object {$_})
    }
    @($Value | ForEach-Object {[string]$_} | ForEach-Object {$_.Trim()} | Where-Object {$_})
}

function Get-NormalizedNavigationPath($Value) {
    (@(ConvertTo-NavigationPathParts $Value) -join ' > ').Trim()
}

function Get-KnowledgeFrontMatter([string]$Text) {
    $match=[regex]::Match($Text,'(?s)\A---\s*\r?\n(.*?)\r?\n---')
    if ($match.Success) { return $match.Groups[1].Value }
    $null
}

function Get-KnowledgeMetaValue([string]$Meta,[string]$Name) {
    $pattern='(?m)^\s*'+[regex]::Escape($Name)+':\s*"?([^"\r\n]+)'
    $match=[regex]::Match($Meta,$pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim().Trim("'") }
    $null
}

function Get-KnowledgeMetaProfiles([string]$Meta) {
    $match=[regex]::Match($Meta,'(?m)^\s*profiles:\s*\[(.*?)\]')
    if (!$match.Success) { return @() }
    @($match.Groups[1].Value.Split(',') | ForEach-Object {$_.Trim().Trim('"').Trim("'")} | Where-Object {$_})
}

function Test-SameKnowledgeValue($Expected,$Actual) {
    [string]::IsNullOrWhiteSpace([string]$Expected) -or ([string]$Expected).Equals([string]$Actual,[StringComparison]::OrdinalIgnoreCase)
}

function Get-ExactStyleKnowledgeMatches($W,$ExtensionConfig) {
    $navigationPath=Get-NormalizedNavigationPath $ExtensionConfig.target.navigation_path
    if ([string]::IsNullOrWhiteSpace($navigationPath)) { return @() }
    $profile=Get-Profile $W ([string]$ExtensionConfig.profile)
    $styleCategories=@('page-style')
    $matches=@()
    $patternRoot=Join-Path $W.Path 'knowledge/patterns'
    if (!(Test-Path -LiteralPath $patternRoot)) { return @() }
    foreach($file in Get-ChildItem -LiteralPath $patternRoot -File -Filter '*.md' | Sort-Object Name) {
        $content=Read-Utf8Text $file.FullName
        $meta=Get-KnowledgeFrontMatter $content
        if (!$meta) { continue }
        $status=Get-KnowledgeMetaValue $meta 'status'
        $category=([string](Get-KnowledgeMetaValue $meta 'category')).ToLowerInvariant()
        if ($status -ne 'Verified' -or $category -notin $styleCategories) { continue }
        $recordPath=Get-NormalizedNavigationPath (Get-KnowledgeMetaValue $meta 'navigation_path')
        if (!$recordPath.Equals($navigationPath,[StringComparison]::OrdinalIgnoreCase)) { continue }
        $profiles=@(Get-KnowledgeMetaProfiles $meta)
        $recordWorkspace=[string](Get-KnowledgeMetaValue $meta 'workspace_id')
        $recordProduct=[string](Get-KnowledgeMetaValue $meta 'product')
        $recordVersion=[string](Get-KnowledgeMetaValue $meta 'version')
        if ([string]::IsNullOrWhiteSpace($recordWorkspace) -or !$recordWorkspace.Equals([string]$W.Id,[StringComparison]::OrdinalIgnoreCase)) { continue }
        if ([string]::IsNullOrWhiteSpace($recordProduct) -or !$recordProduct.Equals([string]$profile.product.name,[StringComparison]::OrdinalIgnoreCase)) { continue }
        if ([string]::IsNullOrWhiteSpace($recordVersion) -or !$recordVersion.Equals([string]$profile.product.version,[StringComparison]::OrdinalIgnoreCase)) { continue }
        if (!$profiles.Count -or [string]$ExtensionConfig.profile -notin $profiles) { continue }
        $matches+=@([pscustomobject]@{
            id=Get-KnowledgeMetaValue $meta 'id';category=$category;navigation_path=$recordPath
            path=$file.FullName.Substring($W.Path.Length).TrimStart('\').Replace('\','/');content=$content
        })
    }
    @($matches)
}

function Get-PrototypeReadinessIssues($W,$ExtensionConfig) {
    $c=Initialize-ExtensionWorkflow $ExtensionConfig
    $issues=@()
    if ([string]$c.delivery.mode -notin @('static','static-demo','embedded-static','backend')) { $issues+='Confirm delivery.mode before collecting prototype requirements.' }
    if (!$c.workflow.delivery_confirmed) { $issues+='Confirm the delivery mode with the user before prototype design.' }
    if ($c.workflow.capability_mode -ne 'legacy' -and $c.delivery.demo_data -eq 'pending') { $issues+='Confirm demo data source: user-provided, generated or none.' }
    if ($c.workflow.capability_mode -ne 'legacy' -and $c.delivery.backend -eq 'pending') { $issues+='Confirm whether backend, API or database work is needed.' }
    if ($c.workflow.capability_mode -ne 'legacy' -and $c.delivery.mode -eq 'backend') {
        if ($c.delivery.backend -ne 'approved') { $issues+='Backend prototype requires delivery.backend=approved.' }
        $p=Get-Profile $W ([string]$c.profile)
        if ($p.database.required -ne $true -or !$p.database.version -or !$p.database.host -or !$p.database.name) { $issues+='Backend prototype requires confirmed database product/version, host and name.' }
    }
    if (!$c.workflow.requirements_confirmed) { $issues+='Prototype requirements have not been confirmed by the user.' }
    if ([string]::IsNullOrWhiteSpace([string]$c.requirements.change_goal)) { $issues+='Missing prototype requirement: change_goal.' }
    if ([string]::IsNullOrWhiteSpace([string]$c.requirements.user_scenario)) { $issues+='Missing prototype requirement: user_scenario.' }
    if (@($c.requirements.inputs).Count -eq 0) { $issues+='Missing prototype requirement: inputs/data sources (use an explicit none/not-applicable entry when appropriate).' }
    if (@($c.requirements.ui_and_interaction).Count -eq 0) { $issues+='Missing prototype requirement: UI and interaction.' }
    if (@($c.requirements.acceptance_criteria).Count -eq 0) { $issues+='Missing prototype requirement: acceptance criteria.' }
    if (@($c.requirements.constraints).Count -eq 0) { $issues+='Missing prototype requirement: constraints.' }
    if (@($c.requirements.out_of_scope).Count -eq 0) { $issues+='Missing prototype requirement: out of scope.' }
    $navigationPath=Get-NormalizedNavigationPath $c.target.navigation_path
    if ([string]::IsNullOrWhiteSpace($navigationPath)) { $issues+='Missing target.navigation_path: record the PLM user click sequence before design.' }
    if ([string]$c.workflow.capability_mode -eq 'legacy' -and [string]$c.delivery.mode -in @('embedded-static','backend') -and @($c.target.mount_sequence).Count -eq 0) { $issues+='Missing target.mount_sequence: record the technical page/menu-to-embedded-page resolution sequence.' }

    $styleMatches=@(Get-ExactStyleKnowledgeMatches $W $c)
    if (!$styleMatches.Count) {
        if ($c.style_context.status -ne 'source-confirmed' -or $c.style_context.user_confirmed -ne $true -or @($c.style_context.evidence).Count -eq 0) {
            $issues+="No exact-path Verified style knowledge for '$navigationPath'. Ask whether to inspect the original PLM page; after inspection, obtain user style confirmation and record style_context as source-confirmed with evidence."
        }
    }

    $requirementText=(@($c.requirements.change_goal)+@($c.requirements.user_scenario)+@($c.requirements.inputs)+@($c.requirements.ui_and_interaction)+@($c.requirements.acceptance_criteria)+@($c.requirements.constraints) -join ' ')
    if ($requirementText -match '(?i)excel|xlsx|xls') {
        if ($c.requirements.data_preview.required -ne $true) { $issues+='Excel parsing requires requirements.data_preview.required=true.' }
        if ([string]$c.requirements.data_preview.mode -notin @('table','native-grid')) { $issues+='Excel parsing results must use data_preview.mode=table or native-grid.' }
        if (@($c.requirements.data_preview.columns).Count -eq 0) { $issues+='Excel parsing results require an explicit data_preview.columns list.' }
        if (@($c.requirements.data_preview.interaction).Count -eq 0) { $issues+='Excel parsing results require data_preview.interaction rules for parsing, row state, scrolling, and validation feedback.' }
    }
    @($issues)
}

function Get-IntegrationReadinessIssues($W,$ExtensionConfig) {
    $c=Initialize-ExtensionWorkflow $ExtensionConfig
    $issues=@()
    if ($c.workflow.capability_mode -notin @('integration','linked')) { $issues+='Integration capability is not selected.' }
    if ($c.workflow.stage -ne 'integration') { $issues+='Integration stage has not started.' }
    if ($c.workflow.capability_mode -eq 'linked' -and !$c.workflow.prototype_accepted) { $issues+='Linked prototype must be accepted before integration.' }
    if (!$c.workflow.requirements_confirmed) { $issues+='Integration requirements have not been confirmed by the user.' }
    if ([string]$c.delivery.mode -notin @('embedded-static','backend')) { $issues+='Integration requires delivery.mode embedded-static or backend.' }
    if ([string]::IsNullOrWhiteSpace([string]$c.integration_requirements.source_artifact)) { $issues+='Missing integration source_artifact: identify the static HTML artifact.' }
    else {
        $artifact=[string]$c.integration_requirements.source_artifact
        $resolved=$(if ([IO.Path]::IsPathRooted($artifact)) {$artifact} else {Join-Path (Join-Path $W.Path "extensions/$($c.id)") $artifact})
        if (!(Test-Path -LiteralPath $resolved -PathType Leaf) -or [IO.Path]::GetExtension($resolved).ToLowerInvariant() -notin @('.html','.htm')) {
            $issues+='Integration source_artifact must resolve to an existing HTML file.'
        }
    }
    if ([string]$c.integration_requirements.source_kind -notin @('extension','user-provided')) { $issues+='Confirm integration source_kind: extension or user-provided.' }
    if ([string]::IsNullOrWhiteSpace([string]$c.integration_requirements.entry_behavior)) { $issues+='Missing integration entry_behavior: describe how the PLM user opens the page.' }
    foreach($name in @('acceptance_criteria','constraints','out_of_scope')) {
        if (@($c.integration_requirements.$name).Count -eq 0) { $issues+="Missing integration requirement: $name." }
    }
    if ([string]::IsNullOrWhiteSpace((Get-NormalizedNavigationPath $c.target.navigation_path))) { $issues+='Missing target.navigation_path: record the PLM click sequence.' }
    if (@($c.target.mount_sequence).Count -eq 0) { $issues+='Missing target.mount_sequence: record menu, registration, container and page resource resolution.' }
    if (!$c.target.module -and !$c.target.menu -and !$c.target.page) { $issues+='Missing target module, menu or page.' }
    $profile=$null
    try { $profile=Get-Profile $W ([string]$c.profile) } catch { $issues+=$_.Exception.Message }
    if ($profile) {
        foreach($key in @('deployment.plm_local_path','application_server.kind','web.url')) {
            $parts=$key.Split('.'); if ([string]::IsNullOrWhiteSpace([string]$profile.($parts[0]).($parts[1]))) { $issues+="Missing integration environment: $key." }
        }
        if ($profile.deployment.mode -in @('virtual-machine','remote-server') -and
            [string]::IsNullOrWhiteSpace([string]$profile.source.access_path)) {
            $issues+='Integration needs an Agent-accessible source path for this remote deployment.'
        }
    }
    if ($c.original_system_change.status -ne 'authorized' -or $c.original_system_change.snapshot_confirmed -ne $true -or
        @($c.original_system_change.approved_paths).Count -eq 0 -or @($c.original_system_change.scope).Count -eq 0) {
        $issues+='Original-system changes require authorized status, confirmed snapshot, approved_paths and scope.'
    }
    if ($c.delivery.mode -eq 'backend' -and $c.delivery.backend -ne 'approved') { $issues+='Backend work requires delivery.backend=approved.' }
    @($issues)
}

function Initialize-ExtensionWorkflow($Config) {
    Add-MissingProperty $Config 'lifecycle' ([ordered]@{status='Active';archived_at=$null;reason=$null})
    Add-MissingProperty $Config 'requirements' (New-RequirementState)
    Add-MissingProperty $Config 'integration_requirements' (New-IntegrationRequirementState)
    Add-MissingProperty $Config 'integration_evidence' (New-IntegrationEvidenceState)
    $integrationDefaults=New-IntegrationRequirementState
    foreach($property in $integrationDefaults.Keys) { Add-MissingProperty $Config.integration_requirements $property $integrationDefaults[$property] }
    $evidenceDefaults=New-IntegrationEvidenceState
    foreach($property in $evidenceDefaults.Keys) { Add-MissingProperty $Config.integration_evidence $property $evidenceDefaults[$property] }
    $requirementDefaults=New-RequirementState
    foreach($property in $requirementDefaults.Keys) { Add-MissingProperty $Config.requirements $property $requirementDefaults[$property] }
    Add-MissingProperty $Config.requirements 'data_preview' ([ordered]@{required=$false;mode='none';columns=@();interaction=@()})
    foreach($property in @('required','mode','columns','interaction')) {
        $default=$requirementDefaults.data_preview[$property]
        Add-MissingProperty $Config.requirements.data_preview $property $default
    }
    Add-MissingProperty $Config 'validation' (New-ValidationState)
    Add-MissingProperty $Config 'knowledge_capture' (New-KnowledgeCaptureState)
    Add-MissingProperty $Config 'style_context' (New-StyleContextState)
    $styleContextDefaults=New-StyleContextState
    foreach($property in $styleContextDefaults.Keys) { Add-MissingProperty $Config.style_context $property $styleContextDefaults[$property] }
    Add-MissingProperty $Config 'iteration_history' @()
    Add-MissingProperty $Config 'result' ([ordered]@{summary=$null;artifacts=@();prototype_review=$null;completed_at=$null})
    Add-MissingProperty $Config.result 'prototype_review' $null
    Add-MissingProperty $Config 'target' ([ordered]@{module=$null;menu=$null;page=$null;navigation_path=@();mount_sequence=@()})
    Add-MissingProperty $Config.target 'navigation_path' @()
    Add-MissingProperty $Config.target 'mount_sequence' @()
    if (@($Config.target.navigation_path).Count -eq 0 -and ![string]::IsNullOrWhiteSpace([string]$Config.target.menu)) {
        $Config.target.navigation_path=@(ConvertTo-NavigationPathParts $Config.target.menu)
    }
    if (!$Config.PSObject.Properties['workflow']) {
        $legacy=[string]$Config.status
        $accepted=$legacy -match '(?i)(DeployedUserVerified|Completed|Accepted)'
        $phase=$(if ($accepted) {'Completed'} elseif ($legacy -match '(?i)PendingUserReview') {'PendingUserReview'} elseif ($legacy -match '(?i)ChangesRequested') {'ChangesRequested'} elseif ($legacy -match '(?i)(Analyzing|Implementation)') {'Implementation'} else {'Requirements'})
        $validation=$(if ($accepted) {'Accepted'} elseif ($phase -eq 'PendingUserReview') {'PendingUserReview'} elseif ($phase -eq 'ChangesRequested') {'ChangesRequested'} else {'NotReady'})
        $Config.validation.status=$validation
        $Config | Add-Member -NotePropertyName workflow -NotePropertyValue ([ordered]@{current_iteration='ITER-001';phase=$phase;delivery_confirmed=$false;requirements_confirmed=$false;next_action=$null})
    } else {
        Add-MissingProperty $Config.workflow 'current_iteration' 'ITER-001'
        Add-MissingProperty $Config.workflow 'phase' 'Requirements'
        Add-MissingProperty $Config.workflow 'delivery_confirmed' $false
        Add-MissingProperty $Config.workflow 'requirements_confirmed' $false
        Add-MissingProperty $Config.workflow 'next_action' $null
    }
    Add-MissingProperty $Config.workflow 'capability_mode' 'legacy'
    Add-MissingProperty $Config.workflow 'stage' 'prototype'
    Add-MissingProperty $Config.workflow 'prototype_accepted' $false
    $Config
}

function Get-ExtensionGuideState($W,$Config) {
    $c=Initialize-ExtensionWorkflow $Config
    $profileId=[string]$c.profile
    $profileLabel='Unbound'
    $product='Unbound'
    $deploymentMode='Unconfigured'
    $deploymentHost=$null
    try {
        $p=Get-Profile $W $profileId
        $profileLabel=$(if ($p.label) {[string]$p.label} else {$profileId})
        $product=$(if ($p.product.name) {[string]$p.product.name+' '+[string]$p.product.version} else {'Unconfigured'})
        $deploymentMode=$(if ($p.deployment.mode) {[string]$p.deployment.mode} else {'Unconfigured'})
        $deploymentHost=[string]$p.deployment.host
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
        id=[string]$c.id;title=[string]$c.title;profile=$profileId;profile_label=$profileLabel;product=$product
        deployment_mode=$deploymentMode;deployment_host=$deploymentHost
        lifecycle=$lifecycle;iteration=[string]$c.workflow.current_iteration;phase=$phase;validation=$validation;next_action=$action
    }
}

function Get-Issues($W,$ExtensionConfig=$null) {
    $c=$W.Config
    if ([string]::IsNullOrWhiteSpace([string]$c.workspace_id)) { 'Missing: workspace_id' }
    if (@(Get-ConfiguredProfileNames $W).Count -eq 0) { 'No configured profiles. Add label, product, version and deployment mode under workspace.yaml.profiles.<id>.' }
    if (!$ExtensionConfig) { return }

    $e=$ExtensionConfig
    if ([string]::IsNullOrWhiteSpace([string]$e.profile)) { 'Extension is not bound to a profile.'; return }
    try { $p=Get-Profile $W $e.profile } catch { $_.Exception.Message; return }
    foreach($key in @('label','product.name','product.version','deployment.mode')) {
        $parts=$key.Split('.'); $value=$(if ($parts.Count -eq 1) {$p.($parts[0])} else {$p.($parts[0]).($parts[1])}); if ([string]::IsNullOrWhiteSpace([string]$value)) { "Missing in profile $($e.profile): $key" }
    }
    if ($p.deployment.mode -in @('virtual-machine','remote-server') -and [string]::IsNullOrWhiteSpace([string]$p.deployment.host)) {
        "Missing in profile $($e.profile): deployment.host"
    }
    $mode=[string]$e.delivery.mode
    if ($mode -notin @('static','static-demo','embedded-static','backend')) { 'Missing/invalid: delivery.mode (static/static-demo/embedded-static/backend)'; return }
    if ($e.workspace_id -ne $c.workspace_id) { 'extension.workspace_id does not match workspace.yaml.' }
    if ($mode -eq 'static-demo' -and $e.delivery.demo_data -notin @('user-provided','generated')) { 'static-demo requires delivery.demo_data user-provided or generated.' }
    if ($mode -in @('embedded-static','backend')) {
        if (!$e.target.module -and !$e.target.menu -and !$e.target.page) { 'Embedded/backend delivery requires a target module, menu or page.' }
        if ([string]::IsNullOrWhiteSpace((Get-NormalizedNavigationPath $e.target.navigation_path))) { 'Embedded/backend delivery requires target.navigation_path (PLM click sequence).' }
        if (@($e.target.mount_sequence).Count -eq 0) { 'Embedded/backend delivery requires target.mount_sequence (technical embedding sequence).' }
        foreach($key in @('os.name','os.version','application_server.kind','application_server.host','web.url','web.login_mode','deployment.plm_local_path')) {
            $parts=$key.Split('.'); $value=$p.($parts[0]).($parts[1]); if ([string]::IsNullOrWhiteSpace([string]$value)) { "Missing for ${mode}: $key" }
        }
    }
    if ($mode -eq 'backend') {
        if ($e.delivery.backend -ne 'approved') { 'backend delivery requires delivery.backend=approved.' }
        if ($p.database.required -ne $true) { 'backend delivery requires database.required=true.' }
        foreach($key in @('version','host','name')) { if (!$p.database.$key) { "Missing for backend: database.$key" } }
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

. "$script:StudioRoot/controller/actions.ps1"
. "$script:StudioRoot/controller/requirements.ps1"
. "$script:StudioRoot/controller/state-machine.ps1"
. "$script:StudioRoot/controller/guards.ps1"
