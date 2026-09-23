[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param([ValidateSet('runtime','extension')][string]$Mode='runtime',[string]$Extension)
. "$PSScriptRoot/../../tools/config/Common.ps1"
$w=Get-Workspace
$archive=Join-Path $script:StudioRoot ('archive/reset-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6))
Assert-Child (Join-Path $script:StudioRoot 'archive') $archive
if ($Mode -eq 'extension' -and !$Extension) { throw '-Extension is required for extension reset.' }
$target=$(if ($Mode -eq 'runtime') { Join-Path $script:StudioRoot 'runtime' } else { (Get-Extension $w $Extension).Path })
Assert-Child $script:StudioRoot $target
if (!$PSCmdlet.ShouldProcess($target,"Archive $Mode to $archive")) { return }
New-Item -ItemType Directory -Path $archive | Out-Null
if (Test-Path -LiteralPath $target) { Move-Item -LiteralPath $target -Destination (Join-Path $archive (Split-Path $target -Leaf)) }
if ($Mode -eq 'runtime') { New-Item -ItemType Directory -Path $target | Out-Null }
Write-Config (Join-Path $archive 'reset.json') @{mode=$Mode;extension=$Extension;created_at=(Get-Date -Format o)}
Write-Output "Archived to $archive. Knowledge and other extensions were preserved."
