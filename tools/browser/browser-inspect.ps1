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

function Get-ChromiumDownloadUrl {
    $metadataUrl='https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json'
    try {
        $metadata=Invoke-RestMethod -Uri $metadataUrl -Method Get -TimeoutSec 30
    } catch {
        throw "Cannot reach Chrome for Testing release metadata ($metadataUrl): $($_.Exception.Message)"
    }
    $stable=$metadata.channels.Stable
    $download=$stable.downloads.chrome | Where-Object { $_.platform -eq 'win64' } | Select-Object -First 1
    if (!$stable.version -or !$download.url) { throw 'Chrome for Testing metadata did not provide a Stable win64 Chrome download.' }
    [pscustomobject]@{Version=$stable.version;Url=$download.url}
}

function Test-ChromiumDownloadUrl([string]$Uri) {
    try {
        $response=Invoke-WebRequest -Uri $Uri -Method Head -TimeoutSec 30 -UseBasicParsing
        if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 400) {
            throw "HTTP status $($response.StatusCode)"
        }
    } catch {
        throw "Chromium download address is unreachable ($Uri): $($_.Exception.Message)"
    }
}

if ($Initialize) {
    if ($p.browser.mode -eq 'cdp') {
        Write-Output 'CDP mode uses the configured browser endpoint; skipping local Chromium media.'
    } elseif (Test-Path -LiteralPath $exe) {
        Write-Output "Using existing Chromium executable: $exe"
    } else {
        if (!(Test-Path -LiteralPath $media)) {
            $release=Get-ChromiumDownloadUrl
            Write-Output "Checking Chromium download address for Stable $($release.Version)..."
            Test-ChromiumDownloadUrl $release.Url
            $mediaDirectory=Split-Path -Parent $media
            New-Item -ItemType Directory -Force -Path $mediaDirectory | Out-Null
            $downloadTemp="$media.download"
            try {
                Write-Output "Downloading Chromium Stable $($release.Version)..."
                Invoke-WebRequest -Uri $release.Url -Method Get -OutFile $downloadTemp -TimeoutSec 1800 -UseBasicParsing
                if (!(Test-Path -LiteralPath $downloadTemp) -or (Get-Item -LiteralPath $downloadTemp).Length -le 0) {
                    throw 'The Chromium download completed without a usable archive.'
                }
                Move-Item -LiteralPath $downloadTemp -Destination $media -Force
            } catch {
                Remove-Item -LiteralPath $downloadTemp -Force -ErrorAction SilentlyContinue
                throw "Chromium download failed: $($_.Exception.Message)"
            }
        }
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
