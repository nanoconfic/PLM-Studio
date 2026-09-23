param(
    [Parameter(Mandatory=$true)][string]$Extension,
    [Parameter(Mandatory=$true)][ValidateSet('Accepted','ChangesRequested')][string]$Result,
    [Parameter(Mandatory=$true)][string]$Feedback
)
& "$PSScriptRoot/../../tools/validation/extension-review.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
