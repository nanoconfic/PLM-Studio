param(
    [Parameter(Mandatory=$true)][string]$Extension,
    [Parameter(Mandatory=$true)][string]$Summary,
    [string[]]$Artifact,
    [string]$KnowledgeFacet='Auto'
)
& "$PSScriptRoot/../../tools/delivery/extension-deliver.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
