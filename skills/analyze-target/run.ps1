param([Parameter(Mandatory=$true)][string]$Extension)
& "$PSScriptRoot/../../tools/source/analyze-target.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
