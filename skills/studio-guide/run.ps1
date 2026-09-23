param([switch]$Json,[switch]$IncludeArchived)
& "$PSScriptRoot/../../tools/workspace/studio-guide.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
