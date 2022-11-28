#!/bin/bash -e

echo "Clone 3dparty yocto layers"

directory="var-fsl-yocto"
bsp_version=${1}

cd ${directory}/sources
git clone https://github.com/hailo-ai/meta-hailo -b ${bsp_version}
git clone https://github.com/shalex88/meta-shalex -b ${bsp_version}
