param([string]$Extension)
& "$PSScriptRoot/../../tools/workspace/workspace-doctor.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
