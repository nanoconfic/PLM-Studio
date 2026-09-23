[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param([ValidateSet('runtime','extension')][string]$Mode='runtime',[string]$Extension)
& "$PSScriptRoot/../../tools/workspace/workspace-reset.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
