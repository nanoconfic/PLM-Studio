param(
    [Parameter(Mandatory=$true)][string]$Extension,
    [ValidateSet('Auto','Resume','NewIteration')][string]$Action='Auto'
)
& "$PSScriptRoot/../../tools/extension/extension-iterate.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
