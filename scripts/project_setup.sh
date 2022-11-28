#!/bin/bash -e

echo "Project setup"

# Set build settings
cd conf
ln -sf ../../../scripts/site.conf site.conf

# Disable sanity test preventing building on nfs
touch sanity.conf

# Add Hailo layers
echo -E '
BBLAYERS += "${BSPDIR}/sources/meta-hailo/meta-hailo-accelerator"
BBLAYERS += "${BSPDIR}/sources/meta-hailo/meta-hailo-libhailort"
BBLAYERS += "${BSPDIR}/sources/meta-hailo/meta-hailo-tappas"
BBLAYERS += "${BSPDIR}/sources/meta-shalex"
' >> bblayers.conf

echo "Done"
