param(
    [string]$SandboxRoot,
    [ValidateSet('auto','powershell','pwsh')][string]$Engine='auto'
)
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (!$SandboxRoot) { $SandboxRoot=[IO.Path]::GetTempPath() }
$sandbox=Join-Path $SandboxRoot ('plm-studio-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox | Out-Null
$excludedWorkspaceRoots=@('.git','archive','extensions','runtime','sources','tools')
Get-ChildItem -LiteralPath $root -Force | Where-Object {$_.Name -notin $excludedWorkspaceRoots} | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $sandbox -Recurse
}
New-Item -ItemType Directory -Path "$sandbox/tools/browser" -Force | Out-Null
Get-ChildItem -LiteralPath "$root/tools" -Directory | Where-Object {$_.Name -ne 'browser'} | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination "$sandbox/tools" -Recurse
}
Copy-Item -LiteralPath "$root/tools/browser/browser-inspect.ps1" -Destination "$sandbox/tools/browser/browser-inspect.ps1"
function Check($Value,$Message) { if (!$Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$shell=$(if ($Engine -ne 'auto') {$Engine} elseif (Get-Command pwsh -ErrorAction SilentlyContinue) {'pwsh'} else {'powershell'})
function Run($Skill,$Arguments) { & $shell -NoProfile -File "$sandbox/skills/$Skill/run.ps1" @Arguments; if ($LASTEXITCODE -ne 0) { throw "$Skill failed: $LASTEXITCODE" } }
function Run-Failure($Skill,$Arguments) {
    $prior=$ErrorActionPreference; $ErrorActionPreference='Continue'
    $output=& $shell -NoProfile -File "$sandbox/skills/$Skill/run.ps1" @Arguments 2>&1 | Out-String
    $exitCode=$LASTEXITCODE; $ErrorActionPreference=$prior
    [pscustomobject]@{ExitCode=$exitCode;Output=$output}
}

$strictUtf8=[System.Text.UTF8Encoding]::new($false,$true)
$activeScripts=@(Get-ChildItem -LiteralPath $sandbox -Recurse -File -Filter '*.ps1' | Where-Object {
    $_.FullName -notmatch '\\archive\\' -and $_.FullName -notmatch '\\node_modules\\' -and $_.FullName -notmatch '\\sources\\mirror\\'
})
$scriptEncodingOk=$true
foreach($scriptFile in $activeScripts) {
    $bytes=[System.IO.File]::ReadAllBytes($scriptFile.FullName)
    try { $null=$strictUtf8.GetString($bytes) } catch { $scriptEncodingOk=$false; break }
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) { $scriptEncodingOk=$false; break }
}
Check ($activeScripts.Count -gt 0 -and $scriptEncodingOk) 'active PowerShell scripts use valid UTF-8 with BOM'

Remove-Item -LiteralPath "$sandbox/extensions" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$sandbox/extensions" | Out-Null
$config="$sandbox/workspace.yaml"
. "$sandbox/scripts/Common.ps1"
$c=Read-Config $config
$c.workspace_id='fixture'; $c.profiles.DEV.product.name='PLM'; $c.profiles.DEV.product.version='1'
$c.profiles.DEV.label='中文环境 UTF-8 验证'
Write-Config $config $c
$roundTrip=Read-Config $config
$configBytes=[System.IO.File]::ReadAllBytes($config)
Check ($roundTrip.profiles.DEV.label -eq '中文环境 UTF-8 验证' -and !($configBytes.Length -ge 3 -and $configBytes[0] -eq 0xEF -and $configBytes[1] -eq 0xBB -and $configBytes[2] -eq 0xBF)) 'config uses strict UTF-8 without BOM and preserves Chinese text'
$invalidUtf8=Join-Path $sandbox 'invalid-utf8.yaml'
[System.IO.File]::WriteAllBytes($invalidUtf8,[byte[]](0x7B,0x22,0x78,0x22,0x3A,0x22,0xFF,0x22,0x7D))
$invalidRejected=$false
try { Read-Config $invalidUtf8 | Out-Null } catch { $invalidRejected=$true }
Check $invalidRejected 'invalid UTF-8 config is rejected'
$fixtureKnowledge=@'
---
id: "KNOW-FIXTURE-STYLE"
status: Verified
category: page-style
applicability:
  workspace_id: "fixture"
  product: "PLM"
  version: "1"
  profiles: ["DEV"]
navigation_path: "系统导航 > 产品数据管理 > Fixture"
---
# Fixture style constraint

MUST_USE_FIXTURE_STYLE
'@
Write-Utf8Text "$sandbox/knowledge/patterns/fixture-style-verified.md" $fixtureKnowledge
Run 'workspace-doctor' @()
$previousErrorAction=$ErrorActionPreference
$ErrorActionPreference='Continue'
$missingProfileOutput=& $shell -NoProfile -File "$sandbox/skills/extension-init/run.ps1" -Title 'Must not exist' -Mode static -NonInteractive 2>$null
$missingProfileExitCode=$LASTEXITCODE
$ErrorActionPreference=$previousErrorAction
Check ($missingProfileExitCode -ne 0 -and @(Get-ChildItem "$sandbox/extensions" -Directory).Count -eq 0) 'missing profile stops before extension directory creation'
Run 'extension-init' @('-Title','Static','-Profile','DEV','-Mode','static')
$initialized=Read-Config "$sandbox/extensions/EXT-001/extension.yaml"
Check ($initialized.workflow.phase -eq 'Requirements' -and $initialized.workflow.delivery_confirmed -eq $true -and $initialized.workflow.requirements_confirmed -eq $false) 'delivery confirmation stops at prototype requirements before implementation'
$controllerJson=& $shell -NoProfile -File "$sandbox/skills/workspace-controller/run.ps1" -Extension EXT-001 -Json
$controller=$controllerJson | ConvertFrom-Json
Check ($LASTEXITCODE -eq 0 -and $controller.phase -eq 'Requirements' -and $controller.requirements_confirmed -eq $false -and 'update_requirements' -in $controller.allowed -and 'inspect_environment' -in $controller.allowed -and 'implement' -in $controller.blocked -and 'deliver' -in $controller.blocked) 'controller exposes requirements-stage allow and block lists'
$directController=& $shell -NoProfile -File "$sandbox/controller/run.ps1" -Extension EXT-001 -Json | ConvertFrom-Json
Check ($LASTEXITCODE -eq 0 -and $directController.phase -eq $controller.phase -and @($directController.allowed).Count -eq @($controller.allowed).Count) 'direct controller and compatibility skill return the same state'
$entry=& $shell -NoProfile -File "$sandbox/controller/run.ps1" -Json | ConvertFrom-Json
Check ($LASTEXITCODE -eq 0 -and @($entry.entry_modes).Count -eq 3 -and @($entry.extensions).Count -eq 1) 'controller provides the natural-language workspace entry without a start command'
$blockedImplementation=& $shell -NoProfile -File "$sandbox/skills/workspace-controller/run.ps1" -Extension EXT-001 -Action implement -Json | ConvertFrom-Json
Check ($LASTEXITCODE -eq 2 -and $blockedImplementation.permitted -eq $false) 'controller rejects implementation before requirements confirmation'
$blockedDelivery=Run-Failure 'extension-deliver' @('-Extension','EXT-001','-Summary','too early')
Check ($blockedDelivery.ExitCode -ne 0 -and $blockedDelivery.Output.Contains('Readiness gate')) 'delivery skill rejects the requirements phase'
$blockedReview=Run-Failure 'extension-review' @('-Extension','EXT-001','-Result','Accepted','-Feedback','too early')
Check ($blockedReview.ExitCode -ne 0 -and $blockedReview.Output.Contains('Workspace Controller')) 'review skill rejects feedback before delivery'
$notReady=Run-Failure 'prototype-preflight' @('-Extension','EXT-001')
Check ($notReady.ExitCode -ne 0 -and $notReady.Output.Contains('Prototype requirements have not been confirmed')) 'prototype preflight blocks implementation before requirements confirmation'
$initialized.target.navigation_path=@('系统导航','产品数据管理','Fixture')
Write-Config "$sandbox/extensions/EXT-001/extension.yaml" $initialized
Run 'workspace-doctor' @('-Extension','EXT-001')
$knowledgeOutput=(& $shell -NoProfile -File "$sandbox/skills/knowledge-context/run.ps1" -Extension EXT-001 -Facet Style | Out-String)
Check ($LASTEXITCODE -eq 0 -and $knowledgeOutput.Contains('MUST_USE_FIXTURE_STYLE') -and $knowledgeOutput.Contains('Applicable Verified constraints')) 'applicable Verified knowledge is injected into extension context'
Run 'extension-init' @('-Title','Demo','-Profile','DEV','-Mode','static-demo','-DemoData','generated')
Check (Test-Path "$sandbox/extensions/EXT-002/brief.md") 'automatic EXT sequence and minimal template'
$previousErrorAction=$ErrorActionPreference
$ErrorActionPreference='Continue'
$unconfirmedOutput=& $shell -NoProfile -File "$sandbox/skills/extension-init/run.ps1" -Title 'Unconfirmed profile' -Profile UAT -CreateProfile -CopyEnvironmentFrom DEV -ProfileLabel 'Fixture UAT' -ProductName PLM -ProductVersion 1 -Mode static -NonInteractive 2>$null
$unconfirmedExitCode=$LASTEXITCODE
$ErrorActionPreference=$previousErrorAction
Check ($unconfirmedExitCode -ne 0 -and !$((Read-Config $config).profiles.PSObject.Properties['UAT']) -and !(Test-Path "$sandbox/extensions/EXT-003")) 'automation cannot create an unconfirmed profile'
Run 'extension-init' @('-Title','Copied environment','-Profile','UAT','-CreateProfile','-CopyEnvironmentFrom','DEV','-ProfileLabel','Fixture UAT','-ProductName','PLM','-ProductVersion','1','-ProfileSetupConfirmed','-Mode','static','-NonInteractive')
$workspaceAfterProfile=Read-Config $config
$createdWithProfile=Read-Config "$sandbox/extensions/EXT-003/extension.yaml"
Check ($workspaceAfterProfile.profiles.UAT.application_server.kind -eq $workspaceAfterProfile.profiles.DEV.application_server.kind -and $createdWithProfile.profile -eq 'UAT') 'new profile can reuse environment and is bound before extension creation'
$newPath=Initialize-ExtensionWorkflow $createdWithProfile
$newPath.target.navigation_path=@('系统导航','产品数据管理','新解析页')
$newPath.requirements.change_goal='Parse a user-selected Excel workbook'
$newPath.requirements.user_scenario='User explicitly parses and validates worksheet rows'
$newPath.requirements.inputs=@('user-provided XLSX')
$newPath.requirements.ui_and_interaction=@('Parse Excel and show rows')
$newPath.requirements.acceptance_criteria=@('Parsed rows are visible')
$newPath.requirements.constraints=@('No persistence')
$newPath.requirements.out_of_scope=@('Backend import')
$newPath.workflow.requirements_confirmed=$true
Write-Config "$sandbox/extensions/EXT-003/extension.yaml" $newPath
$newPathBlocked=Run-Failure 'prototype-preflight' @('-Extension','EXT-003')
Check ($newPathBlocked.ExitCode -ne 0 -and $newPathBlocked.Output.Contains('No exact-path Verified style knowledge') -and $newPathBlocked.Output.Contains('data_preview.required=true')) 'new paths require confirmed source style and Excel table metadata'
$newPath=Read-Config "$sandbox/extensions/EXT-003/extension.yaml"
$newPath.style_context.status='source-confirmed'; $newPath.style_context.source='original-product'; $newPath.style_context.user_confirmed=$true; $newPath.style_context.evidence=@('evidence/original-page-style.json')
$newPath.requirements.data_preview.required=$true; $newPath.requirements.data_preview.mode='table'; $newPath.requirements.data_preview.columns=@('Row','Code','Status'); $newPath.requirements.data_preview.interaction=@('Explicit parse action','Sticky header and isolated scrolling','Per-row validation state')
Write-Config "$sandbox/extensions/EXT-003/extension.yaml" $newPath
Run 'prototype-preflight' @('-Extension','EXT-003')
$newPath=Read-Config "$sandbox/extensions/EXT-003/extension.yaml"
Check ($newPath.workflow.phase -eq 'Implementation') 'confirmed new-path style plus table preview passes prototype preflight'
$legacy=Read-Config "$sandbox/extensions/EXT-002/extension.yaml"
$legacy.PSObject.Properties.Remove('workflow'); $legacy.PSObject.Properties.Remove('validation'); $legacy.PSObject.Properties.Remove('requirements'); $legacy.status='Draft'
Write-Config "$sandbox/extensions/EXT-002/extension.yaml" $legacy
$guideJson=& $shell -NoProfile -File "$sandbox/skills/studio-guide/run.ps1" -Json
$guide=$guideJson | ConvertFrom-Json
$guidedExt=@($guide.extensions | Where-Object { $_.id -eq 'EXT-002' })[0]
Check ($guidedExt.next_action -eq 'CollectRequirements') 'guide keeps legacy draft extension selectable and infers requirements flow'
Run 'extension-iterate' @('-Extension','EXT-002','-Action','Auto')
$legacy=Read-Config "$sandbox/extensions/EXT-002/extension.yaml"
Check ($legacy.workflow.current_iteration -eq 'ITER-001' -and @($legacy.iteration_history).Count -eq 0) 'legacy draft resumes without creating a false iteration'

$source=Join-Path $sandbox 'fixture-source'; New-Item -ItemType Directory "$source/App","$source/Other" -Force | Out-Null
Write-Utf8Text "$source/App/app.cs" 'class Example {}'; Write-Utf8Text "$source/Other/ignored.cs" 'class Ignored {}'
$c=Read-Config $config; $c.profiles.DEV.deployment.mode='local'; $c.profiles.DEV.deployment.host='localhost'; $c.profiles.DEV.deployment.plm_local_path=$source; $c.profiles.DEV.source.auto_discover=$false; $c.profiles.DEV.source.candidate_paths=@(); $c.profiles.DEV.source.access_path=$source
Write-Config $config $c
Run 'source-sync' @('-Extension','EXT-001','-Scope','App')
Check ((Test-Path "$sandbox/sources/mirror/DEV/App/app.cs") -and !(Test-Path "$sandbox/sources/mirror/DEV/Other/ignored.cs") -and (Test-Path "$sandbox/sources/manifests/EXT-001/source-manifest-DEV.yaml")) 'scoped extension source sync'
Run 'analyze-target' @('-Extension','EXT-001')
Check (@(Get-ChildItem "$sandbox/knowledge/environment-snapshots" -Filter '*.yaml').Count -ge 1) 'analysis environment snapshot'
$e=Read-Config "$sandbox/extensions/EXT-001/extension.yaml"
$e.requirements.change_goal='Fixture goal'; $e.requirements.user_scenario='Fixture user'; $e.requirements.inputs=@('generated fixture input'); $e.requirements.ui_and_interaction=@('Fixture page interaction'); $e.requirements.acceptance_criteria=@('Fixture result works'); $e.requirements.constraints=@('No production writes'); $e.requirements.out_of_scope=@('Backend integration'); $e.workflow.requirements_confirmed=$true
Write-Config "$sandbox/extensions/EXT-001/extension.yaml" $e
Run 'prototype-preflight' @('-Extension','EXT-001')
$allowedImplementation=& $shell -NoProfile -File "$sandbox/skills/workspace-controller/run.ps1" -Extension EXT-001 -Action implement -Json | ConvertFrom-Json
Check ($LASTEXITCODE -eq 0 -and $allowedImplementation.permitted -eq $true) 'controller allows implementation after preflight'
Run 'extension-deliver' @('-Extension','EXT-001','-Summary','fixture delivered','-Artifact','prototype/index.html')
$pendingController=& $shell -NoProfile -File "$sandbox/skills/workspace-controller/run.ps1" -Extension EXT-001 -Json | ConvertFrom-Json
Check ('review' -in $pendingController.allowed -and 'deliver' -in $pendingController.blocked) 'controller permits review only after delivery'
Run 'extension-review' @('-Extension','EXT-001','-Result','Accepted','-Feedback','fixture accepted')
Run 'extension-iterate' @('-Extension','EXT-001','-Action','Auto')
$e=Read-Config "$sandbox/extensions/EXT-001/extension.yaml"
Check ($e.profile -eq 'DEV' -and $e.lifecycle.status -eq 'Active' -and $e.workflow.current_iteration -eq 'ITER-002' -and @($e.iteration_history).Count -eq 1) 'accepted iteration closes while extension stays active and selectable'

Run 'extension-init' @('-Title','Prototype only','-Profile','DEV','-CapabilityMode','prototype','-Mode','static','-NonInteractive')
$prototypeQuestions=& $shell -NoProfile -File "$sandbox/controller/run.ps1" -Extension EXT-004 -Json | ConvertFrom-Json
Check ($prototypeQuestions.capability_mode -eq 'prototype' -and @($prototypeQuestions.missing).Count -gt 0 -and 'implement' -in $prototypeQuestions.blocked) 'controller asks for missing prototype inputs before implementation'
$p=Read-Config "$sandbox/extensions/EXT-004/extension.yaml"
$p.target.navigation_path=@('系统导航','产品数据管理','Fixture')
$p.requirements.change_goal='Show a static PLM page'; $p.requirements.user_scenario='User reviews an item'
$p.requirements.inputs=@('none'); $p.requirements.ui_and_interaction=@('Open and inspect item')
$p.requirements.acceptance_criteria=@('HTML page opens'); $p.requirements.constraints=@('No writes'); $p.requirements.out_of_scope=@('Embedding')
$p.workflow.requirements_confirmed=$true
Write-Config "$sandbox/extensions/EXT-004/extension.yaml" $p
Run 'prototype-preflight' @('-Extension','EXT-004')
Write-Utf8Text "$sandbox/extensions/EXT-004/prototype/index.html" '<!doctype html><title>Fixture</title>'
Run 'extension-deliver' @('-Extension','EXT-004','-Summary','prototype fixture','-Artifact','prototype/index.html')
Run 'extension-review' @('-Extension','EXT-004','-Result','Accepted','-Feedback','prototype accepted')
$p=Read-Config "$sandbox/extensions/EXT-004/extension.yaml"
Check ($p.workflow.capability_mode -eq 'prototype' -and $p.workflow.phase -eq 'Completed') 'prototype-only mode closes after HTML review'

Run 'extension-init' @('-Title','Integration only','-Profile','DEV','-CapabilityMode','integration','-Mode','embedded-static','-NonInteractive')
$i=Read-Config "$sandbox/extensions/EXT-005/extension.yaml"
$i.target.module='PDM'; $i.target.navigation_path=@('系统导航','产品数据管理','Fixture'); $i.target.mount_sequence=@('menu','registration','iframe','html')
$i.integration_requirements.source_artifact="$sandbox/extensions/EXT-004/prototype/index.html"
$i.integration_requirements.source_kind='user-provided'; $i.integration_requirements.entry_behavior='Open from the PDM menu'
$i.integration_requirements.acceptance_criteria=@('Page opens in PLM'); $i.integration_requirements.constraints=@('Static only'); $i.integration_requirements.out_of_scope=@('Backend')
$i.original_system_change.status='authorized'; $i.original_system_change.snapshot_confirmed=$true
$i.original_system_change.approved_paths=@("$source/App/app.cs"); $i.original_system_change.scope=@('menu registration')
$i.workflow.requirements_confirmed=$true
Write-Config "$sandbox/extensions/EXT-005/extension.yaml" $i
Run 'integration-preflight' @('-Extension','EXT-005')
$missingEvidence=Run-Failure 'extension-deliver' @('-Extension','EXT-005','-Summary','too early')
Check ($missingEvidence.ExitCode -ne 0 -and $missingEvidence.Output.Contains('Integration evidence is incomplete')) 'integration delivery rejects missing file evidence'
$i=Read-Config "$sandbox/extensions/EXT-005/extension.yaml"
New-Item -ItemType Directory -Path "$sandbox/fixture-backup" -Force | Out-Null
$before=(Get-FileHash "$source/App/app.cs" -Algorithm SHA256).Hash
Copy-Item -LiteralPath "$source/App/app.cs" -Destination "$sandbox/fixture-backup/app.cs"
Add-Utf8Text "$source/App/app.cs" ' // integration fixture'
$after=(Get-FileHash "$source/App/app.cs" -Algorithm SHA256).Hash
$i.integration_evidence.changes=@([ordered]@{path="$source/App/app.cs";backup="$sandbox/fixture-backup/app.cs";before_sha256=$before;after_sha256=$after;diff='Added integration fixture'})
$i.integration_evidence.verification=@('Menu and HTML opened'); $i.integration_evidence.rollback='Restore fixture backup'
Write-Config "$sandbox/extensions/EXT-005/extension.yaml" $i
Run 'extension-deliver' @('-Extension','EXT-005','-Summary','integration fixture','-Artifact','evidence.md')
Run 'extension-review' @('-Extension','EXT-005','-Result','Accepted','-Feedback','integration accepted')
$i=Read-Config "$sandbox/extensions/EXT-005/extension.yaml"
Check ($i.workflow.capability_mode -eq 'integration' -and $i.workflow.phase -eq 'Completed') 'integration-only mode closes without prototype design'

Run 'extension-init' @('-Title','Linked','-Profile','DEV','-CapabilityMode','linked','-Mode','embedded-static','-NonInteractive')
$linked=Read-Config "$sandbox/extensions/EXT-006/extension.yaml"
$linked.delivery.demo_data='none'; $linked.target.navigation_path=@('系统导航','产品数据管理','Fixture')
$linked.requirements.change_goal='Show a linked static page'; $linked.requirements.user_scenario='User opens PLM page'
$linked.requirements.inputs=@('none'); $linked.requirements.ui_and_interaction=@('Inspect item')
$linked.requirements.acceptance_criteria=@('HTML opens'); $linked.requirements.constraints=@('Static only'); $linked.requirements.out_of_scope=@('Backend')
$linked.workflow.requirements_confirmed=$true
Write-Config "$sandbox/extensions/EXT-006/extension.yaml" $linked
Run 'prototype-preflight' @('-Extension','EXT-006')
Write-Utf8Text "$sandbox/extensions/EXT-006/prototype/index.html" '<!doctype html><title>Linked</title>'
Run 'extension-deliver' @('-Extension','EXT-006','-Summary','linked prototype','-Artifact','prototype/index.html')
Run 'extension-review' @('-Extension','EXT-006','-Result','Accepted','-Feedback','prototype accepted')
$linked=Read-Config "$sandbox/extensions/EXT-006/extension.yaml"
Check ($linked.workflow.stage -eq 'integration' -and $linked.workflow.phase -eq 'Requirements' -and !$linked.workflow.requirements_confirmed -and $linked.integration_requirements.source_artifact -eq 'prototype/index.html') 'linked mode enters integration requirements after prototype acceptance'
$linked.target.module='PDM'; $linked.target.mount_sequence=@('menu','registration','iframe','html')
$linked.integration_requirements.entry_behavior='Open from menu'; $linked.integration_requirements.acceptance_criteria=@('PLM opens linked page')
$linked.integration_requirements.constraints=@('Static only'); $linked.integration_requirements.out_of_scope=@('Backend')
$linked.original_system_change.status='authorized'; $linked.original_system_change.snapshot_confirmed=$true
$linked.original_system_change.approved_paths=@("$source/App/app.cs"); $linked.original_system_change.scope=@('menu registration')
$linked.workflow.requirements_confirmed=$true
Write-Config "$sandbox/extensions/EXT-006/extension.yaml" $linked
Run 'integration-preflight' @('-Extension','EXT-006')
$linked=Read-Config "$sandbox/extensions/EXT-006/extension.yaml"
$before=(Get-FileHash "$source/App/app.cs" -Algorithm SHA256).Hash
Copy-Item -LiteralPath "$source/App/app.cs" -Destination "$sandbox/fixture-backup/app-linked.cs"
Add-Utf8Text "$source/App/app.cs" ' // linked fixture'
$after=(Get-FileHash "$source/App/app.cs" -Algorithm SHA256).Hash
$linked.integration_evidence.changes=@([ordered]@{path="$source/App/app.cs";backup="$sandbox/fixture-backup/app-linked.cs";before_sha256=$before;after_sha256=$after;diff='Added linked fixture'})
$linked.integration_evidence.verification=@('Linked page opened'); $linked.integration_evidence.rollback='Restore fixture backup'
Write-Config "$sandbox/extensions/EXT-006/extension.yaml" $linked
Run 'extension-deliver' @('-Extension','EXT-006','-Summary','linked integration','-Artifact','evidence.md')
Run 'extension-review' @('-Extension','EXT-006','-Result','Accepted','-Feedback','integration accepted')
$linked=Read-Config "$sandbox/extensions/EXT-006/extension.yaml"
Check ($linked.workflow.phase -eq 'Completed' -and $linked.workflow.prototype_accepted -eq $true) 'linked mode closes after both reviews'
$resetPreview=& $shell -NoProfile -File "$sandbox/skills/workspace-reset/run.ps1" -Mode runtime -WhatIf 2>&1 | Out-String
Check ($LASTEXITCODE -eq 0 -and $resetPreview -match '(?i)What if|WhatIf') 'runtime reset preview'
Write-Output "All self-tests passed. Isolated artifacts retained at $sandbox"
