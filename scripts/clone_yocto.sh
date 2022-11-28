#!/bin/bash -e

echo "Clone yocto sources"

directory="var-fsl-yocto"
bsp_version="zeus"
src_version="imx-5.4.70-2.3.2-var01"

# create the directory
mkdir -p ${directory}
pushd ${directory}

# Configure google repo
git config --global user.name "Alex Sh"
git config --global user.email "shalex.work@gmail.com"
git config --global color.ui true

# Clone poky and other layers
repo init -u https://github.com/varigit/variscite-bsp-platform.git -b fsl-${bsp_version} -m ${src_version}.xml
repo sync -j4

popd

# Clone 3dparty
source "$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"/clone_3dparty.sh ${bsp_version}

echo "Done"
