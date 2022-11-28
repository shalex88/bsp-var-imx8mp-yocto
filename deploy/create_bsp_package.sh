#!/bin/bash -e

usage()
{
	echo -e "usage:"
	echo -e "\t./$(basename $0) -r REVISION [options]"
	echo -e "options:"
	echo -e "\t-h - help"
	echo -e "\t-r - revision to create"
	echo -e "example:"
	echo -e "\t./$(basename $0) -r 3"
}

get_latest_bsp()
{
	BSP_FILE_PATH=${BUILD_DIR}/tmp/deploy/images/${BSP_MACHINE_NAME}
	cp ${BSP_FILE_PATH}/${BSP_IMAGE_NAME}-${BSP_MACHINE_NAME}.tar.gz ${BSP_PACKAGE_NAME}/${BSP_FILE}
	cp ${BSP_FILE_PATH}/imx-boot ${BSP_PACKAGE_NAME}/${UBOOT_FILE}
	cp ${BSP_FILE_PATH}/${DT_FILE} ${BSP_PACKAGE_NAME}/${DT_FILE}
	cp ${BSP_FILE_PATH}/${BOOT_SCR_FILE} ${BSP_PACKAGE_NAME}/${BOOT_SCR_FILE}

	cp ${BSP_FILE_PATH}/${BSP_IMAGE_NAME}-${BSP_MACHINE_NAME}.manifest ${BSP_PACKAGE_NAME}/${BSP_PACKAGES_FILE}
	cp "$(ls -d ${BUILD_DIR}/tmp/deploy/licenses/${BSP_IMAGE_NAME}-* | tail -1)"/license.manifest ${BSP_PACKAGE_NAME}/${LICENSE_FILE}
}

get_latest_sdk()
{
	SDK_FILE_PATH=${BUILD_DIR}/tmp/deploy/sdk

	cp ${SDK_FILE_PATH}/${SDK}.sh ${BSP_PACKAGE_NAME}/sdk.sh
	cat ${SDK_FILE_PATH}/${SDK}.host.manifest > ${BSP_PACKAGE_NAME}/${SDK_PACKAGES_FILE}
	cat ${SDK_FILE_PATH}/${SDK}.target.manifest >> ${BSP_PACKAGE_NAME}/${SDK_PACKAGES_FILE}
}

get_versions()
{
	UBOOT_VER=$(strings ${BSP_PACKAGE_NAME}/${UBOOT_FILE} | grep "U-Boot SPL" | awk -F" " '{print $1,$2,$3}')
	DT_VER=$(strings ${BSP_PACKAGE_NAME}/${DT_FILE} | grep "My Version" | awk -F" " '{print $3}')
	BOOTSCR_VER=$(strings ${BSP_PACKAGE_NAME}/${BOOT_SCR_FILE} | grep "My Version" | awk -F" " '{print $4}')
	ROOTFS_VER=$(ls ${BSP_FILE_PATH}/${BSP_IMAGE_NAME}-${BSP_MACHINE_NAME}-*.tar.gz | awk -F"." '{print $1}' | awk -F"-" '{print $NF}')
	KERNEL_VER=$(cat ${BSP_FILE_PATH}/${BSP_IMAGE_NAME}-${BSP_MACHINE_NAME}-*.rootfs.manifest | grep imx8mp+ -m 1 | awk -F" " '{print $1}' | awk -F"kernel-" '{print $NF}')
	DEVICE_MODEL=$(strings ${BSP_PACKAGE_NAME}/${DT_FILE} | grep 7 -m1 | cut -c 2-)

	echo "Device = ${DEVICE_MODEL}" > ${BSP_PACKAGE_NAME}/${VERSION_FILE}
	echo "Uboot = ${UBOOT_VER}" >> ${BSP_PACKAGE_NAME}/${VERSION_FILE}
	echo "Kernel = ${KERNEL_VER}" >> ${BSP_PACKAGE_NAME}/${VERSION_FILE}
	echo "Device Tree = ${DT_VER}" >> ${BSP_PACKAGE_NAME}/${VERSION_FILE}
	echo "Boot Script = ${BOOTSCR_VER}" >> ${BSP_PACKAGE_NAME}/${VERSION_FILE}
	echo "RootFS = ${ROOTFS_VER}" >> ${BSP_PACKAGE_NAME}/${VERSION_FILE}
}

archive()
{
	zip -r ${VERSIONED_BSP_PACKAGE_NAME}.zip ${BSP_PACKAGE_NAME}
}

upload()
{
	# TODO: upload via layout to be able to download the latest revision
	MY_TOKEN=$(cat jf_token)
	curl --oauth2-bearer ${MY_TOKEN} -T ${VERSIONED_BSP_PACKAGE_NAME}.zip "http://artifactory/artifactory/bsp/${BSP_MACHINE_NAME}/${BSP_IMAGE_NAME}/${VERSIONED_BSP_PACKAGE_NAME}.zip"
}

# Input arguments
while getopts "r:h" OPTION;
do
	case ${OPTION} in
	r)
		# TODO: automate revision increment
		REVISION=${OPTARG}
		;;
	h)
		usage
		exit 0
		;;
	?)
		usage
		exit 1
		;;
	esac
done
shift "$(($OPTIND -1))"

# Mandatory arguments
if [ -z "$REVISION" ]; then
	usage
	exit 1
fi

# Global variables
# TODO: make build dir path generic and not hard coded
BUILD_DIR=/nfs/bsp/bsp-imx8mp-zeus/var-fsl-yocto/build
BSP_IMAGE_NAME=fsl-image-qt5
BSP_MACHINE_NAME=imx8mp-var-dart-aion
UBOOT_FILE=imx-boot-sd.bin
BSP_FILE=rootfs.tar.gz
DT_FILE=${BSP_MACHINE_NAME}.dtb
BOOT_SCR_FILE=boot.scr
SDK=fsl-imx-xwayland-glibc-x86_64-${BSP_IMAGE_NAME}-aarch64-${BSP_MACHINE_NAME}-toolchain-*
BSP_PACKAGE_NAME=${BSP_IMAGE_NAME}-${BSP_MACHINE_NAME}
VERSIONED_BSP_PACKAGE_NAME=${BSP_PACKAGE_NAME}-${REVISION}
VERSION_FILE=bsp_version.txt
BSP_PACKAGES_FILE=bsp_packages.txt
SDK_PACKAGES_FILE=sdk_packages.txt
LICENSE_FILE=bsp_licenses.txt

# Main
mkdir -p ${BSP_PACKAGE_NAME}

get_latest_sdk
get_latest_bsp

get_versions

archive

# upload

echo "BSP package was successfully created"
cat ${BSP_PACKAGE_NAME}/${VERSION_FILE}
