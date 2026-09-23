param(
    [Parameter(Mandatory=$true)][string]$Extension,
    [string]$Facet='Auto'
)
& "$PSScriptRoot/../../tools/knowledge/knowledge-context.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
