#!/bin/bash -e

blue_underlined_bold_echo()
{
	echo -e "\e[34m\e[4m\e[1m$@\e[0m"
}

blue_bold_echo()
{
	echo -e "\e[34m\e[1m$@\e[0m"
}

red_bold_echo()
{
	echo -e "\e[31m\e[1m$@\e[0m"
}

IMGS_PATH=$(pwd)
ROOTFS_IMAGE=rootfs.tar.gz
DISPLAY=lvds
PART=p
ROOTFSPART=1
ROOTFS2PART=2
APPPART=3
EXTENDPART=4
FACTORUPART=5
PERDATAPART=6
BOOTDIR=/boot
CURRENT_PART=$(fw_printenv -n mmcpart)

check_board()
{
	if grep -q "i.MX8MM" /sys/devices/soc0/soc_id; then
		BOARD=imx8mm-var-dart
		DTB_PREFIX=fsl-imx8mm-var-dart
		BLOCK=mmcblk2
		BOOTLOADER_OFFSET=33
	elif grep -q "i.MX8MN" /sys/devices/soc0/soc_id; then
		BOARD=imx8mn-var-som
		DTB_PREFIX=fsl-imx8mn-var-som
		BLOCK=mmcblk2
		BOOTLOADER_OFFSET=32
	elif grep -q "i.MX8MP" /sys/devices/soc0/soc_id; then
		BOARD=imx8mp-var-dart
		BLOCK=mmcblk2
		BOOTLOADER_OFFSET=32
	elif grep -q "i.MX8QXP" /sys/devices/soc0/soc_id; then
		BOARD=imx8qxp-var-som
		DTB_PREFIX=fsl-imx8qxp-var-som
		BLOCK=mmcblk0
		BOOTLOADER_OFFSET=32
	elif grep -q "i.MX8QM" /sys/devices/soc0/soc_id; then
		BOARD=imx8qm-var-som
		DTB_PREFIX=fsl-imx8qm-var-som
		BLOCK=mmcblk0
		BOOTLOADER_OFFSET=32

		if [[ $DISPLAY != "lvds" && $DISPLAY != "hdmi" && \
		      $DISPLAY != "dp" ]]; then
			red_bold_echo "ERROR: invalid display, should be lvds, hdmi or dp"
			exit 1
		fi
	elif grep -q "i.MX8MQ" /sys/devices/soc0/soc_id; then
		BOARD=imx8mq-var-dart
		DTB_PREFIX=fsl-imx8mq-var-dart
		BLOCK=mmcblk0
		BOOTLOADER_OFFSET=33
		if [[ $DISPLAY != "lvds" && $DISPLAY != "hdmi" && \
		      $DISPLAY != "dp" && $DISPLAY != "lvds-dp" && $DISPLAY != "lvds-hdmi" ]]; then
			red_bold_echo "ERROR: invalid display, should be lvds, hdmi, dp, lvds-dp or lvds-hdmi"
			exit 1
		fi
	else
		red_bold_echo "ERROR: Unsupported board"
		exit 1
	fi

#TODO: check if we are in SD-Card

	if [[ ! -b /dev/${BLOCK} ]] ; then
		red_bold_echo "ERROR: Can't find eMMC device (/dev/${BLOCK})."
		red_bold_echo "Please verify you are using the correct options for your SOM."
		exit 1
	fi
}

check_images()
{
	if [[ ! -f $IMGS_PATH/$ROOTFS_IMAGE ]] ; then
		red_bold_echo "ERROR: \"$IMGS_PATH/$ROOTFS_IMAGE\" does not exist"
		exit 1
	fi
}

format_emmc_parts()
{
	local ROOTFSPART=$1

	sudo umount /run/media/${BLOCK}p${ROOTFSPART}

	blue_underlined_bold_echo "Formatting partition"
	mkfs.ext4 /dev/${BLOCK}p${ROOTFSPART}  -L rootfs${ROOTFSPART}
	sync; sleep 1
}

install_rootfs_to_emmc()
{
	echo

	local ROOTFSPART=$1
	local ROOTFS_IMAGE=$2

	blue_underlined_bold_echo "Installing rootfs [${ROOTFSPART}] ${ROOTFS_IMAGE}"
	MOUNTDIR=/run/media/${BLOCK}p${ROOTFSPART}
	mkdir -p ${MOUNTDIR}
	mount /dev/${BLOCK}p${ROOTFSPART} ${MOUNTDIR}

	printf "Extracting files"
	tar --warning=no-timestamp -xpf ${IMGS_PATH}/${ROOTFS_IMAGE} -C ${MOUNTDIR} --checkpoint=.1200

	if [[ ${BOARD} = "imx8mq-var-dart" ]]; then
		# Create DTB symlinks
		(cd ${MOUNTDIR}/${BOOTDIR}; ln -fs ${DTB_PREFIX}-wifi-${DISPLAY}.dtb ${DTB_PREFIX}.dtb)
		(cd ${MOUNTDIR}/${BOOTDIR}; ln -fs ${DTB_PREFIX}-wifi-${DISPLAY}-cb12.dtb ${DTB_PREFIX}-cb12.dtb)

		# Update variscite-blacklist.conf
		echo "blacklist fec" >> ${MOUNTDIR}/etc/modprobe.d/variscite-blacklist.conf
	fi

	if [[ ${BOARD} = "imx8qxp-var-som" ]]; then
		# Create DTB symlink
		(cd ${MOUNTDIR}/${BOOTDIR}; ln -fs ${DTB_PREFIX}-wifi.dtb ${DTB_PREFIX}.dtb)
	fi

	if [[ ${BOARD} = "imx8qm-var-som" ]]; then
		# Create DTB symlinks
		(cd ${MOUNTDIR}/${BOOTDIR}; ln -fs ${DTB_PREFIX}-${DISPLAY}.dtb ${DTB_PREFIX}.dtb)
		(cd ${MOUNTDIR}/${BOOTDIR}; ln -fs fsl-imx8qm-var-spear-${DISPLAY}.dtb fsl-imx8qm-var-spear.dtb)
	fi

	# Adjust u-boot-fw-utils for eMMC on the installed rootfs
	if [ -f ${MOUNTDIR}/etc/fw_env.config ]; then
		sed -i "s/\/dev\/mmcblk./\/dev\/${BLOCK}/" ${MOUNTDIR}/etc/fw_env.config
	fi

	echo
	sync

	umount ${MOUNTDIR}
}


install_bsp_suplement_to_emmc()
{
	echo

	local ROOTFSPART=$1

	blue_underlined_bold_echo "Installing bsp suplement to rootfs ${ROOTFSPART}"

	MOUNTDIR=/run/media/${BLOCK}p${ROOTFSPART}
	mkdir -p ${MOUNTDIR}
	mount /dev/${BLOCK}p${ROOTFSPART} ${MOUNTDIR}

	printf "Set mount points for new partitions"
	echo "/dev/mmcblk2p3		/oper		auto    defaults              	0  0" >> ${MOUNTDIR}/etc/fstab
	echo "/dev/mmcblk2p6 		/data		auto	defaults		0  0" >> ${MOUNTDIR}/etc/fstab

	sync

	mkdir -p ${MOUNTDIR}/oper
	mount /dev/mmcblk2p3 ${MOUNTDIR}/oper

	cp -r ${MOUNTDIR}/oper-org/* ${MOUNTDIR}/oper/
	rm -r ${MOUNTDIR}/oper-org

	sync
}

stop_udev()
{
	if [ -f /lib/systemd/system/systemd-udevd.service ]; then
		systemctl -q stop \
			systemd-udevd-kernel.socket \
			systemd-udevd-control.socket \
			systemd-udevd
	fi
}

start_udev()
{
	if [ -f /lib/systemd/system/systemd-udevd.service ]; then
		systemctl -q start \
			systemd-udevd-kernel.socket \
			systemd-udevd-control.socket \
			systemd-udevd
	fi
}

usage()
{
	echo
	echo "This script installs Yocto on the SOM's internal storage device"
	echo
	echo " Usage: $(basename $0) <option>"
	echo
	echo " options:"
	echo " -h                           show help message"
	if grep -q "i.MX8QM" /sys/devices/soc0/soc_id; then
		echo " -d <lvds|hdmi|dp>            set display type, default is lvds"
	elif grep -q "i.MX8MQ" /sys/devices/soc0/soc_id; then
		echo " -d <lvds|hdmi|dp|lvds-dp|lvds-hdmi>  set display type, default is lvds"
	fi
	echo " -u                           create two rootfs partitions (for swUpdate double-copy)."
	echo
}

finish()
{
	echo
	blue_bold_echo "Yocto installed successfully"
	exit 0
}

#################################################
#           Execution starts here               #
#################################################

if [[ $EUID != 0 ]] ; then
	red_bold_echo "This script must be run with super-user privileges"
	exit 1
fi

blue_underlined_bold_echo "*** Variscite MX8 Yocto eMMC Recovery ***"
echo

while getopts d:h OPTION;
do
	case $OPTION in
	d)
		DISPLAY=$OPTARG
		;;
	h)
		usage
		exit 0
		;;
	*)
		usage
		exit 1
		;;
	esac
done

check_board

printf "Board: "
blue_bold_echo $BOARD

printf "Installing to internal storage device: "
blue_bold_echo eMMC

blue_bold_echo "Current Partition ${CURRENT_PART}"
if [ ${CURRENT_PART} == 1 ]; then
	NEW_PARTITION=2
elif [ ${CURRENT_PART} == 2 ]; then
	NEW_PARTITION=1
fi

check_images
stop_udev
format_emmc_parts ${NEW_PARTITION}
install_rootfs_to_emmc ${NEW_PARTITION} rootfs.tar.gz
install_bsp_suplement_to_emmc ${NEW_PARTITION}

echo
blue_bold_echo "Switch to rootfs${NEW_PARTITION}"
fw_setenv mmcpart ${NEW_PARTITION}

start_udev
finish
