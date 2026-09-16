param([switch]$Json,[switch]$IncludeArchived)
& "$PSScriptRoot/skills/studio-guide/run.ps1" -Json:$Json -IncludeArchived:$IncludeArchived
exit $LASTEXITCODE
