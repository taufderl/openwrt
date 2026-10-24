platform_check_image() {
	legacy_sdcard_check_image "$1"
}

platform_copy_config() {
	local partdev

	if export_partdevice partdev 1; then
		mount -t vfat -o rw,noatime "/dev/$partdev" /mnt
		cp -af "$UPGRADE_BACKUP" "/mnt/$BACKUP_FILE"
		umount /mnt
	fi
}

# The Fingbox keeps its vendor U-Boot between 8 KiB and 1 MiB of the eMMC
# and cannot be recovered over FEL, so never write that area: write the
# partition table, then each partition. Also works from an initramfs,
# where the boot device is unknown (the eMMC is mmcblk0 via DT alias).
fingbox_do_upgrade() {
	local disk=/dev/mmcblk0
	local part start size

	sync
	get_image_dd "$1" of=/tmp/image.bs count=1 bs=512
	get_partitions /tmp/image.bs image
	[ -s /tmp/partmap.image ] || {
		v "No partitions found in the image."
		return 1
	}

	v "Writing partition table to $disk..."
	dd if=/tmp/image.bs of="$disk" bs=512 count=1 conv=fsync
	partx -d - "$disk"
	partx -a - "$disk"

	while read part start size; do
		v "Writing image to ${disk}p$part..."
		get_image_dd "$1" of="${disk}p$part" ibs=512 obs=1M \
			skip="$start" count="$size" conv=fsync
	done < /tmp/partmap.image
}

platform_do_upgrade() {
	case "$(board_name)" in
	fing,fingbox)
		fingbox_do_upgrade "$1"
		;;
	*)
		legacy_sdcard_do_upgrade "$1"
		;;
	esac
}
