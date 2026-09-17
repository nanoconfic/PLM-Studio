param(
    [Parameter(Mandatory=$true)][string]$Title,
    [string]$Profile,
    [switch]$CreateProfile,
    [string]$CopyEnvironmentFrom,
    [string]$ProfileConfigPath,
    [string]$ProfileLabel,
    [string]$ProductName,
    [string]$ProductVersion,
    [ValidateSet('virtual-machine','local','remote-server')][string]$DeploymentMode,
    [string]$DeploymentHost,
    [string]$PlmLocalPath,
    [string]$SourceAccessPath,
    [string]$WebUrl,
    [string]$ApplicationServerKind,
    [string]$ApplicationServerVersion,
    [ValidateSet('yes','no')][string]$DatabaseRequired,
    [string]$DatabaseVersion,
    [string]$DatabaseHost,
    [string]$DatabaseName,
    [string]$OsName,
    [string]$OsVersion,
    [switch]$ProfileSetupConfirmed,
    [switch]$NonInteractive,
    [ValidateSet('static','static-demo','embedded-static','backend')][string]$Mode,
    [ValidateSet('none','user-provided','generated','pending')][string]$DemoData,
    [string]$Module,[string]$Menu,[string]$Page
)

# Compatibility entry point: forward parameters without decoding and recreating run.ps1.
& (Join-Path $PSScriptRoot 'run.ps1') @PSBoundParameters
if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE }
