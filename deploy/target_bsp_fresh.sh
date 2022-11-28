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
UBOOT_IMAGE=imx-boot-sd.bin
UBOOT_IMAGE_MX8MQ_DP=imx-boot-imx8mq-var-dart-sd.bin-flash_dp_evk
ROOTFS_IMAGE=rootfs.tar.gz
BOOTLOADER_RESERVED_SIZE=8
DISPLAY=lvds
PART=p
ROOTFSPART=1
ROOTFS2PART=2
APPPART=3
EXTENDPART=4
FACTORYPART=5
PERDATAPART=6
BOOTDIR=/boot

KILO=1024
MEGA=1024*$KILO
GIGA=1024*$MEGA

ROOTFS_SIZE=6*$GIGA
FACTORY_DEFAULT_SIZE=${ROOTFS_SIZE}
APPLICATION_OPER=500*$MEGA

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
	if [[ ! -f $IMGS_PATH/$UBOOT_IMAGE ]] ; then
		red_bold_echo "ERROR: \"$IMGS_PATH/$UBOOT_IMAGE\" does not exist"
		exit 1
	fi

	if [[ ! -f $IMGS_PATH/$ROOTFS_IMAGE ]] ; then
		red_bold_echo "ERROR: \"$IMGS_PATH/$ROOTFS_IMAGE\" does not exist"
		exit 1
	fi
}

delete_emmc()
{
	echo
	blue_underlined_bold_echo "Deleting current partitions"

	umount /dev/${BLOCK}${PART}* 2>/dev/null || true

	for ((i=1; i<=16; i++)); do
		if [[ -e /dev/${BLOCK}${PART}${i} ]]; then
			dd if=/dev/zero of=/dev/${BLOCK}${PART}${i} bs=1M count=1 2>/dev/null || true
		fi
	done
	sync

	dd if=/dev/zero of=/dev/${BLOCK} bs=1M count=${BOOTLOADER_RESERVED_SIZE}

	sync; sleep 1
}

create_emmc_parts()
{
	echo
	blue_underlined_bold_echo "Creating new partitions"

	TOTAL_SECTORS=`cat /sys/block/${BLOCK}/size`
	SECT_SIZE_BYTES=`cat /sys/block/${BLOCK}/queue/hw_sector_size`

	BOOTLOADER_RESERVED_SIZE_BYTES=$((BOOTLOADER_RESERVED_SIZE * 1024 * 1024))

	BOOTLOADER_RESERVED_SECT_SIZE=$((BOOTLOADER_RESERVED_SIZE_BYTES / SECT_SIZE_BYTES))
	ROOTFS_SECT_SIZE=$((ROOTFS_SIZE / SECT_SIZE_BYTES))
	APPLICATION_OPER_SECT_SIZE=$((APPLICATION_OPER / SECT_SIZE_BYTES))
	FACTORY_DEFAULT_SECT_SIZE=$((FACTORY_DEFAULT_SIZE / SECT_SIZE_BYTES))

	ROOTFS1_PART_START=$((BOOTLOADER_RESERVED_SECT_SIZE))
	ROOTFS2_PART_START=$((ROOTFS1_PART_START + ROOTFS_SECT_SIZE))
	APP_OPER_PART_START=$((ROOTFS2_PART_START + ROOTFS_SECT_SIZE))

	EXTEND_PART_START=$((APP_OPER_PART_START + APPLICATION_OPER_SECT_SIZE ))
	EXTEND_PART_END=$((TOTAL_SECTORS))
	FACTORY_PART_START=$((EXTEND_PART_START + 1 ))
	PER_DATA_START=$((FACTORY_PART_START + FACTORY_DEFAULT_SECT_SIZE))

	ROOTFS1_PART_END=$((ROOTFS2_PART_START -1))
	ROOTFS2_PART_END=$((APP_OPER_PART_START - 1))
	APP_OPER_PART_END=$((EXTEND_PART_START -1))
	FACTORY_PART_END=$((PER_DATA_START - 1))
	PER_DATA_END=$((TOTAL_SECTORS - 1))

	if [[ $ROOTFS1_PART_START == 0 ]] ; then
		ROOTFS1_PART_START=""
	fi

	(echo n; echo p; echo $ROOTFSPART;  echo $ROOTFS1_PART_START; echo $ROOTFS1_PART_END; \
	 echo n; echo p; echo $ROOTFS2PART; echo $ROOTFS2_PART_START; echo $ROOTFS2_PART_END; \
	 echo n; echo p; echo $APPPART;     echo $APP_OPER_PART_START; echo $APP_OPER_PART_END; \
	 echo n; echo e; echo $EXTENDPART;  echo $EXTEND_PART_START ; echo ; \
	 echo n; echo $FACTORYPART ; echo ; echo $FACTORY_PART_START; echo $FACTORY_PART_END; \
	 echo n; echo $PERDATAPART ; echo ; echo ; \
	 echo w) | fdisk -u /dev/${BLOCK} > /dev/null

	sync; sleep 1
	fdisk -u -l /dev/${BLOCK}
}

format_emmc_parts()
{
	echo
	blue_underlined_bold_echo "Formatting partitions"
	mkfs.ext4 /dev/${BLOCK}${PART}${ROOTFSPART}  -L rootfs1
	mkfs.ext4 /dev/${BLOCK}${PART}${ROOTFS2PART} -L rootfs2
	mkfs.ext4 /dev/${BLOCK}${PART}${APPPART}     -L app
	mkfs.ext4 /dev/${BLOCK}${PART}${FACTORYPART} -L factory
	mkfs.ext4 /dev/${BLOCK}${PART}${PERDATAPART} -L perdata
	sync; sleep 1
}

install_bootloader_to_emmc()
{
	echo
	blue_underlined_bold_echo "Installing booloader"

	if [[ ${BOARD} = "imx8mq-var-dart" && ( ${DISPLAY} = "dp" || ${DISPLAY} = "lvds-dp" ) ]]; then
		UBOOT_IMAGE=${UBOOT_IMAGE_MX8MQ_DP}
	fi

	dd if=${IMGS_PATH}/${UBOOT_IMAGE} of=/dev/${BLOCK} bs=1K seek=${BOOTLOADER_OFFSET}
	sync; sleep 1
}

install_rootfs_to_emmc()
{
	echo

	local ROOTFSPART=$1
	local ROOTFS_IMAGE=$2


	blue_underlined_bold_echo "Installing rootfs [${ROOTFSPART}] ${ROOTFS_IMAGE}"
	MOUNTDIR=/run/media/${BLOCK}${PART}${ROOTFSPART}
	mkdir -p ${MOUNTDIR}
	mount /dev/${BLOCK}${PART}${ROOTFSPART} ${MOUNTDIR}

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

	MOUNTDIR=/run/media/${BLOCK}${PART}${ROOTFSPART}
	mkdir -p ${MOUNTDIR}
	mount /dev/${BLOCK}${PART}${ROOTFSPART} ${MOUNTDIR}

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

check_images
stop_udev
delete_emmc
create_emmc_parts
format_emmc_parts
install_bootloader_to_emmc
install_rootfs_to_emmc ${ROOTFSPART} rootfs.tar.gz
install_rootfs_to_emmc ${ROOTFS2PART} rootfs.tar.gz
install_bsp_suplement_to_emmc ${ROOTFSPART}
install_bsp_suplement_to_emmc ${ROOTFS2PART}

start_udev
finish
