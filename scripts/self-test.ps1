param(
    [string]$SandboxRoot,
    [ValidateSet('auto','powershell','pwsh')][string]$Engine='auto'
)
& "$PSScriptRoot/../tools/validation/self-test.ps1" @PSBoundParameters
