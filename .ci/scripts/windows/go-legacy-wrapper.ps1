Param(
    [string]$ScriptToExecute,
    [hashtable]$ScriptParameters = @{}
)

# The Go toolchain pinned in go.mod targets Windows 10 and later. To produce
# binaries that still start on Windows 7, 8 and 8.1 we build with
# go-legacy-win7, a fork of Go that tracks the same upstream version while
# keeping the legacy Windows fallbacks:
#     https://github.com/thongtech/go-legacy-win7
#
# This wrapper downloads the pinned release, verifies its checksum, puts the
# fork's go command first on PATH and runs $ScriptToExecute with it.
# Keep the version, URL, archive name and checksum in sync when bumping Go.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$goLegacyVersion = "1.27.4-1"
$goLegacyArchive = "go-legacy-win7-$goLegacyVersion.windows_amd64.zip"
$goLegacyUrl = "https://github.com/thongtech/go-legacy-win7/releases/download/v$goLegacyVersion/$goLegacyArchive"
$goLegacySha256 = "f8718d445d4a65590027cca434f164d665a04ee2dde96d7a3dc0abad840b6c2d"
$goLegacyRootDir = "go-legacy-win7"

$tempPath = [System.IO.Path]::GetTempPath()
$fullPath = Join-Path -Path $tempPath -ChildPath ("go_legacy_win7_" + (Get-Random))

$oldPath = $env:Path
$oldGoRoot = $env:GOROOT
$oldGoToolchain = $env:GOTOOLCHAIN

try {
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null

    $destinationFile = Join-Path -Path $fullPath -ChildPath $goLegacyArchive
    Write-Host "Downloading go-legacy-win7 from: $goLegacyUrl"
    Invoke-WebRequest -Uri $goLegacyUrl -OutFile $destinationFile

    $actualSha256 = (Get-FileHash -Path $destinationFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSha256 -ne $goLegacySha256) {
        throw "Checksum mismatch for ${goLegacyArchive}: expected $goLegacySha256, got $actualSha256"
    }
    Write-Host "Checksum verified for $goLegacyArchive"

    Expand-Archive -Path $destinationFile -DestinationPath $fullPath -Force

    $goRoot = Join-Path -Path $fullPath -ChildPath $goLegacyRootDir
    $goBinPath = Join-Path -Path $goRoot -ChildPath "bin"

    # Set GOROOT explicitly so the fork is never mixed with another install.
    $env:GOROOT = $goRoot
    $env:Path = "$goBinPath;$($env:Path)"
    # go.mod pins an exact go version and the fork reports that same version.
    # "local" stops the go command from downloading the upstream toolchain,
    # which would silently drop Windows 7/8/8.1 support.
    $env:GOTOOLCHAIN = "local"

    go env GOROOT
    go version

    & $ScriptToExecute @ScriptParameters
    if ($LASTEXITCODE -ne 0) {
        throw "$ScriptToExecute failed with exit code $LASTEXITCODE"
    }
} finally {
    $env:Path = $oldPath
    if ($null -eq $oldGoRoot) {
        Remove-Item Env:\GOROOT -ErrorAction SilentlyContinue
    } else {
        $env:GOROOT = $oldGoRoot
    }
    if ($null -eq $oldGoToolchain) {
        Remove-Item Env:\GOTOOLCHAIN -ErrorAction SilentlyContinue
    } else {
        $env:GOTOOLCHAIN = $oldGoToolchain
    }

    if (Test-Path -Path $fullPath) {
        Remove-Item -Path $fullPath -Recurse -Force
    }
}
