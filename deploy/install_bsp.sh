#!/bin/bash -e

# TODO: copy to NFS instead target

usage()
{
	echo -e "usage:"
	echo -e "\t./$(basename $0) -t TARGET_IP [options]"
	echo -e "options:"
	echo -e "\t-h - help"
	echo -e "\t-r - revision to install. Latest by default"
	echo -e "\t-f - fresh install"
	echo -e "example:"
	echo -e "\t./$(basename $0) -t 10.199.250.4 -r 2 -f"
}

transfer_and_validate()
{
	FILE=${1}

	script -q -c "scp ${FILE} ${TARGET}:${DESTINATION_DIR}"
	${EXEC_ON_TARGET} "sync"

	LOCAL_MD5SUM=$(md5sum ${FILE} | cut -d ' ' -f1)
	REMOTE_MD5SUM=$(${EXEC_ON_TARGET} "md5sum ${FILE} | cut -d ' ' -f1")

	if [ "${LOCAL_MD5SUM}" != "${REMOTE_MD5SUM}" ]; then
		echo -e "Error: Not matching md5sum!"
		exit
	fi
}

get_latest_bsp()
{
	echo -e "Get latest BSP:"

	# TODO: remove the hard coded names, get it from input
	BSP_IMAGE_NAME=fsl-image-qt5
	BSP_MACHINE_NAME=imx8mp-var-dart-aion
	BSP_PACKAGE_NAME=${BSP_IMAGE_NAME}-${BSP_MACHINE_NAME}
	VERSIONED_BSP_PACKAGE_NAME=${BSP_PACKAGE_NAME}-${REVISION}

	if [ ! -f "${VERSIONED_BSP_PACKAGE_NAME}.zip" ]; then
		DOWNLOAD="wget -q --show-progress --progress=bar http://artifactory/artifactory/bsp/${BSP_MACHINE_NAME}/${BSP_IMAGE_NAME}/${VERSIONED_BSP_PACKAGE_NAME}.zip -P $(pwd)/"
		if  ! $($DOWNLOAD); then
			echo -e "Error: BSP download failed"
			exit 1
		fi
	fi

	if [ ! -f "${VERSIONED_BSP_PACKAGE_NAME}" ]; then
		unzip -o ${VERSIONED_BSP_PACKAGE_NAME}.zip
	fi

	pushd ${BSP_PACKAGE_NAME} > /dev/null

	echo -e "Done"

	echo -e "BSP vesion"
	cat bsp_version.txt
}

target_flash_mode()
{
	# TODO: TBD
	echo -e "Enter flash mode on target:"

	# TODO: currently new install works only when the doard is booted from nfs or sdcard
	# fw_setenv serverip 10.199.250.35
	# fw_setenv nfsroot /nfs/bsp/bsp-netboot/imx8mp/rootfs
	# fw_setenv bootcmd "run netboot"
	# reboot
	echo -e "Done"
}

copy_to_target()
{
	echo -e "Copy files to target:"

	transfer_and_validate ${BSP_FILE}
	transfer_and_validate ${UBOOT_FILE}
	popd > /dev/null
	transfer_and_validate ${TARGET_INSTALL_SCRIPT}

	echo -e "Done"
}

cleanup()
{
	echo -e "Cleanup:"

	${EXEC_ON_TARGET} "rm ${BSP_FILE}"
	${EXEC_ON_TARGET} "rm ${UBOOT_FILE}"
	${EXEC_ON_TARGET} "rm ${TARGET_INSTALL_SCRIPT}"

	echo -e "Done"
}


check_taget_connection()
{
	echo -n "Test target connection"
	target_ip=${1}
	while ! ping -c 1 -w 1 -n ${target_ip} &> /dev/null; do
		echo -n "."
	done
	echo ""
	echo "Connected"
}


TARGET_INSTALL_SCRIPT=target_bsp_update.sh
# TODO: get revision from yocto build
REVISION=3

# Input arguments
while getopts "t:fr:h" OPTION;
do
	case ${OPTION} in
	t)
		TARGET_IP=${OPTARG}
		;;
	f)
		TARGET_INSTALL_SCRIPT=target_bsp_fresh.sh
		;;
	r)
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
if [ -z "$TARGET_IP" ]; then
	usage
	exit 1
fi

# Global variables
TARGET_USER=root
TARGET=${TARGET_USER}@${TARGET_IP}
EXEC_ON_TARGET="ssh ${TARGET}"
DESTINATION_DIR=/home/root/

UBOOT_FILE=imx-boot-sd.bin
BSP_FILE=rootfs.tar.gz

# Main
check_taget_connection ${TARGET_IP}

DEVICE_SERIAL_NUMBER=$(${EXEC_ON_TARGET} "tr -d '\0' < /proc/device-tree/serial-number")

mkdir -p log

(
	date +%d-%m-%Y-%H:%M
	echo -e "System SN ${DEVICE_SERIAL_NUMBER}"

	get_latest_bsp

	target_flash_mode

	copy_to_target

	echo -e "Install:"
	${EXEC_ON_TARGET} "./${TARGET_INSTALL_SCRIPT} 2>&1"

	cleanup

	echo -e "Reboot target:"
	${EXEC_ON_TARGET} "nohup reboot &>/dev/null & exit"
	echo -e "Done"

	# TODO: Not connecting, IP has changed
	# Ping until disconnected
	# while [ ping -c 1 ${TARGET_IP} &> /dev/null ]; do
	# 	sleep 1
	# 	echo -n "."
	# done

	# Ping until connected
	# while [ ! ping -c 1 ${TARGET_IP} &> /dev/null ]; do
	# 	echo -n "."
	# done

	# echo -e "System is alive"

	# ${EXEC_ON_TARGET} "/usr/bin/get-bsp-version"

	echo -e "BSP install is finished"
	echo -e "Log log/bsp_install_${DEVICE_SERIAL_NUMBER}.log"
) 2>&1 | tee log/bsp_install_${DEVICE_SERIAL_NUMBER}.log