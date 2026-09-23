param([Parameter(Mandatory=$true)][string]$Extension)
. "$PSScriptRoot/../../tools/config/Common.ps1"
$w=Get-Workspace
$ext=Get-Extension $w $Extension
$e=$ext.Config
Assert-ControllerAction $w $e 'inspect_environment' | Out-Null
$issues=@(Get-Issues $w $e); if ($issues.Count) { throw ($issues -join "`n") }
$knowledgeFacets=@('Environment')
if ($e.delivery.mode -in @('embedded-static','backend') -or $e.target.module -or $e.target.menu -or $e.target.page) { $knowledgeFacets+='Integration' }
& "$script:StudioRoot/skills/knowledge-context/run.ps1" -Extension $Extension -Facet ($knowledgeFacets -join ',')
$snapshot=New-Snapshot $w $e.profile
$e.environment_snapshot=$snapshot
$e.status='Analyzing'
Write-Config (Join-Path $ext.Path 'extension.yaml') $e
$evidence=Join-Path $ext.Path 'evidence.md'
if (!(Test-Path -LiteralPath $evidence)) { Write-Utf8Text $evidence "# Evidence`n" }
Add-Utf8Text $evidence "`n## Analysis session $(Get-Date -Format o)`nEnvironment snapshot: $snapshot`nStatus: evidence collection pending; not Verified.`n"
Write-Output 'Snapshot created. Collect only the evidence required by the extension delivery mode.'
