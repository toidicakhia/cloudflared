Param(
    # Signs the produced binaries with the same Key Vault certificate as the
    # standard Windows builds. Requires the KEY_VAULT_* variables.
    [switch]$Sign
)

# Builds the Windows 7/8/8.1 binaries. Run it through
# go-legacy-wrapper.ps1, which puts the go-legacy-win7 toolchain on PATH:
#     .\go-legacy-wrapper.ps1 -ScriptToExecute .\builds-legacy.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$env:TARGET_OS = "windows"
$env:LOCAL_OS = "windows"
$TIMESTAMP_RFC3161 = "http://timestamp.digicert.com"

New-Item -Path ".\artifacts" -ItemType Directory -Force | Out-Null

function Sign-Binary {
    param([string]$BinaryPath)

    if (-not $Sign) {
        Write-Output "Skipping signing of $BinaryPath"
        return
    }

    azuresigntool.exe sign -kvu $env:KEY_VAULT_URL -kvi "$env:KEY_VAULT_CLIENT_ID" -kvs "$env:KEY_VAULT_SECRET" -kvc $env:KEY_VAULT_CERTIFICATE -kvt $env:KEY_VAULT_TENANT_ID -tr "$TIMESTAMP_RFC3161" -d "Cloudflare Tunnel Daemon" $BinaryPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to sign $BinaryPath"
    }
}

Write-Output "Building legacy Windows 7/8/8.1 binary for amd64"
$env:TARGET_ARCH = "amd64"
$env:LOCAL_ARCH = "amd64"
# Keep cgo off: a cgo build imports the Universal C Runtime DLLs, which are not
# present on stock Windows 7. CGO_ENABLED=0 also uses Go's internal linker, so
# the go-legacy-win7 stamp is applied. This mirrors the Windows 386 build and
# means the generic (non-cgo) ICMP proxy is used.
$env:CGO_ENABLED = "0"
& make cloudflared
if ($LASTEXITCODE -ne 0) { throw "Failed to build legacy cloudflared for amd64" }
Sign-Binary ".\cloudflared.exe"
copy .\cloudflared.exe .\artifacts\cloudflared-windows-amd64-legacy.exe

Write-Output "Building legacy Windows 7/8/8.1 binary for 386"
$env:TARGET_ARCH = "386"
$env:LOCAL_ARCH = "386"
$env:CGO_ENABLED = "0"
& make cloudflared
if ($LASTEXITCODE -ne 0) { throw "Failed to build legacy cloudflared for 386" }
Sign-Binary ".\cloudflared.exe"
copy .\cloudflared.exe .\artifacts\cloudflared-windows-386-legacy.exe
