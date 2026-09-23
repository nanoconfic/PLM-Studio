param([Parameter(Mandatory=$true)][string]$Extension,[switch]$DiscoverOnly,[string[]]$Scope)
& "$PSScriptRoot/../../tools/source/source-sync.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
