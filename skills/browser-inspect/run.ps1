param([Parameter(Mandatory=$true)][string]$Extension,[switch]$Initialize,[switch]$Run)
& "$PSScriptRoot/../../tools/browser/browser-inspect.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
