Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$env:TARGET_OS = "windows"
$env:LOCAL_OS = "windows"
$TIMESTAMP_RFC3161 = "http://timestamp.digicert.com"

New-Item -Path ".\artifacts" -ItemType Directory

Write-Output "Downloading Go modules"
go mod download
if ($LASTEXITCODE -ne 0) { throw "Failed to download Go modules" }
# Module downloads must not change the committed dependency lockfiles.
git diff --exit-code -- go.mod go.sum
if ($LASTEXITCODE -ne 0) { throw "Go module download changed module metadata" }

Write-Output "Building for amd64"
$env:TARGET_ARCH = "amd64"
$env:LOCAL_ARCH = "amd64"
$env:CGO_ENABLED = 1
& make cloudflared
if ($LASTEXITCODE -ne 0) { throw "Failed to build cloudflared for amd64" }
# Sign build
azuresigntool.exe sign -kvu $env:KEY_VAULT_URL -kvi "$env:KEY_VAULT_CLIENT_ID" -kvs "$env:KEY_VAULT_SECRET" -kvc "$env:KEY_VAULT_CERTIFICATE" -kvt "$env:KEY_VAULT_TENANT_ID" -tr "$TIMESTAMP_RFC3161" -d "Cloudflare Tunnel Daemon" .\cloudflared.exe
copy .\cloudflared.exe .\artifacts\cloudflared-windows-amd64.exe

Write-Output "Building for 386"
$env:TARGET_ARCH = "386"
$env:LOCAL_ARCH = "386"
$env:CGO_ENABLED = 0
& make cloudflared
if ($LASTEXITCODE -ne 0) { throw "Failed to build cloudflared for 386" }
## Sign build
azuresigntool.exe sign -kvu $env:KEY_VAULT_URL -kvi "$env:KEY_VAULT_CLIENT_ID" -kvs "$env:KEY_VAULT_SECRET" -kvc "$env:KEY_VAULT_CERTIFICATE" -kvt "$env:KEY_VAULT_TENANT_ID" -tr "$TIMESTAMP_RFC3161" -d "Cloudflare Tunnel Daemon" .\cloudflared.exe
copy .\cloudflared.exe .\artifacts\cloudflared-windows-386.exe

# The toolchain pinned in go.mod targets Windows 10 and later. Build the
# Windows 7/8/8.1 binaries separately with the go-legacy-win7 fork, which is
# pinned and checksum-verified in go-legacy-wrapper.ps1.
Write-Output "Building legacy Windows 7/8/8.1 binaries"
& (Join-Path $PSScriptRoot "go-legacy-wrapper.ps1") -ScriptToExecute (Join-Path $PSScriptRoot "builds-legacy.ps1") -ScriptParameters @{ Sign = $true }
if ($LASTEXITCODE -ne 0) { throw "Failed to build legacy Windows 7/8/8.1 binaries" }
