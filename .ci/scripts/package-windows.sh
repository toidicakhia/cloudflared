#!/bin/bash
set -e -u -o pipefail

python3 -m venv env
. env/bin/activate
pip install pynacl==1.4.0 pygithub==1.55

VERSION=$(git describe --tags --always --match "[0-9][0-9][0-9][0-9].*.*")
echo $VERSION

export TARGET_OS=windows
# This controls the directory the built artifacts go into
export BUILT_ARTIFACT_DIR=artifacts/
export FINAL_ARTIFACT_DIR=artifacts/
mkdir -p $BUILT_ARTIFACT_DIR
mkdir -p $FINAL_ARTIFACT_DIR
windowsArchs=("amd64" "386")
for arch in ${windowsArchs[@]}; do
    export TARGET_ARCH=$arch
    # Copy .exe from artifacts directory
    cp $BUILT_ARTIFACT_DIR/cloudflared-windows-$arch.exe ./cloudflared.exe
    make cloudflared-msi
    # Copy msi into final directory
    mv cloudflared-$VERSION-$arch.msi $FINAL_ARTIFACT_DIR/cloudflared-windows-$arch.msi

    # Package the Windows 7/8/8.1 binary produced by builds-legacy.ps1 as well.
    # It is installed by the same product definition, so a legacy install is
    # upgraded in place by the standard MSI and vice versa.
    legacyBinary="$BUILT_ARTIFACT_DIR/cloudflared-windows-$arch-legacy.exe"
    if [ -f "$legacyBinary" ]; then
        cp $legacyBinary ./cloudflared.exe
        make cloudflared-msi
        mv cloudflared-$VERSION-$arch.msi $FINAL_ARTIFACT_DIR/cloudflared-windows-$arch-legacy.msi
    fi
done
