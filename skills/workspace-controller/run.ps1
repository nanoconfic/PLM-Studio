param(
    [string]$Extension,
    [ValidateSet('inspect_workspace','create_extension','inspect_environment','inspect_knowledge','update_requirements','confirm_requirements','preflight','implement','deliver','review','start_iteration')][string]$Action,
    [switch]$Json
)
& "$PSScriptRoot/../../controller/run.ps1" @PSBoundParameters
if ((Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue) -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
