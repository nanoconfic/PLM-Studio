param([Parameter(Mandatory=$true)][string]$Extension,[switch]$Initialize,[switch]$Run)
. "$PSScriptRoot/../../tools/config/Common.ps1"
$w=Get-Workspace; $e=(Get-Extension $w $Extension).Config; $p=Get-Profile $w $e.profile
if (!$p.web.url -or !$p.web.login_mode) { throw 'Maintain web.url and web.login_mode in workspace.yaml before browser inspection.' }
if ($p.browser.mode -eq 'cdp' -and !$p.browser.cdp_endpoint) { throw 'Maintain browser.cdp_endpoint in workspace.yaml.' }
if ($p.web.login_mode -eq 'storage-state' -and !$p.browser.storage_state_ref) { throw 'Maintain browser.storage_state_ref.' }
if (!(Get-Command node -ErrorAction SilentlyContinue)) { throw 'Install Node.js.' }

$media=Join-Path $script:StudioRoot 'tools/browser/media/chrome-win64.zip'
$browserRoot=Join-Path $script:StudioRoot 'tools/browser/chromium'
$exe=Join-Path $browserRoot 'chrome-win64/chrome.exe'
if ($p.browser.PSObject.Properties['executable_path'] -and $p.browser.executable_path) { $exe=Join-Path $script:StudioRoot $p.browser.executable_path }
if ($Initialize) {
    if (!(Test-Path -LiteralPath $exe)) {
        if (!(Test-Path -LiteralPath $media)) { throw "Missing shared Chromium media: $media" }
        New-Item -ItemType Directory -Force -Path $browserRoot | Out-Null
        Expand-Archive -LiteralPath $media -DestinationPath $browserRoot -Force
    }
    if (!(Test-Path "$script:StudioRoot/scripts/browser/node_modules/playwright")) {
        Push-Location "$script:StudioRoot/scripts/browser"
        try { & npm install; if ($LASTEXITCODE) { throw 'npm install failed.' } } finally { Pop-Location }
    }
}
if (!(Test-Path "$script:StudioRoot/scripts/browser/node_modules/playwright")) { throw 'Playwright dependency is missing. Run browser-inspect -Initialize.' }
if ($p.browser.mode -ne 'cdp' -and !(Test-Path -LiteralPath $exe)) { throw 'Shared Chromium is missing. Run browser-inspect -Initialize.' }
if ($p.browser.mode -eq 'cdp') { try { $null=Invoke-RestMethod ($p.browser.cdp_endpoint.TrimEnd('/')+'/json/version') -TimeoutSec 5 } catch { throw 'CDP endpoint is unreachable.' } }
if ($Run) { & node "$script:StudioRoot/scripts/browser/inspect.mjs" "$($w.Path)/workspace.yaml" $e.profile $Extension $exe; if ($LASTEXITCODE) { throw 'Browser inspection failed.' } }
else { Write-Output "Browser prerequisites OK. Shared executable: $exe" }
