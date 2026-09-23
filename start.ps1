param([switch]$Json,[switch]$IncludeArchived)
& "$PSScriptRoot/controller/run.ps1" -Json:$Json
exit $LASTEXITCODE
