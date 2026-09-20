param(
    [string]$SandboxRoot,
    [ValidateSet('auto','powershell','pwsh')][string]$Engine='auto'
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (!$SandboxRoot) { $SandboxRoot=[IO.Path]::GetTempPath() }
$sandbox=Join-Path $SandboxRoot ('plm-studio-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox | Out-Null
$excludedWorkspaceRoots=@('.git','archive','extensions','runtime','sources','tools')
Get-ChildItem -LiteralPath $root -Force | Where-Object {$_.Name -notin $excludedWorkspaceRoots} | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $sandbox -Recurse
}
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
    $_.FullName -notmatch '\\archive\\' -and $_.FullName -notmatch '\\node_modules\\' -and $_.FullName -notmatch '\\sources\\mirror\\' -and $_.FullName -notmatch '\\tools\\browser\\'
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
Run 'extension-deliver' @('-Extension','EXT-001','-Summary','fixture delivered','-Artifact','prototype/index.html')
Run 'extension-review' @('-Extension','EXT-001','-Result','Accepted','-Feedback','fixture accepted')
Run 'extension-iterate' @('-Extension','EXT-001','-Action','Auto')
$e=Read-Config "$sandbox/extensions/EXT-001/extension.yaml"
Check ($e.profile -eq 'DEV' -and $e.lifecycle.status -eq 'Active' -and $e.workflow.current_iteration -eq 'ITER-002' -and @($e.iteration_history).Count -eq 1) 'accepted iteration closes while extension stays active and selectable'
& $shell -NoProfile -File "$sandbox/skills/workspace-reset/run.ps1" -Mode runtime -WhatIf
Check ($LASTEXITCODE -eq 0) 'runtime reset preview'
Write-Output "All self-tests passed. Isolated artifacts retained at $sandbox"
