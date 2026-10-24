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

mbr_u32() { # <file> <offset>
	hexdump -s "$2" -n 4 -e '1/4 "%u"' "$1"
}

# Keep MBR entries 3 and 4 of the disk (user data partitions) unless the
# image uses them, they overlap the image's partitions, or sysupgrade -p.
fingbox_keep_extra_partitions() { # <image-bs> <disk>
	local img="$1" disk="$2" n off start end

	[ "$UPGRADE_OPT_SAVE_PARTITIONS" = "0" ] && return 0

	dd if="$disk" of=/tmp/disk.bs bs=512 count=1 2>/dev/null
	end=0
	for n in 0 1 2 3; do
		off=$((446 + n * 16))
		start=$(mbr_u32 "$img" $((off + 8)))
		[ "$start" -gt 0 ] || continue
		start=$((start + $(mbr_u32 "$img" $((off + 12)))))
		[ "$start" -gt "$end" ] && end=$start
	done

	for n in 2 3; do
		off=$((446 + n * 16))
		[ "$(mbr_u32 "$img" $((off + 8)))" -eq 0 ] || continue
		start=$(mbr_u32 /tmp/disk.bs $((off + 8)))
		[ "$start" -gt 0 ] || continue
		if [ "$start" -lt "$end" ]; then
			v "Partition $((n + 1)) overlaps the new layout, dropping it."
			continue
		fi
		v "Keeping partition $((n + 1)) of $disk."
		dd if=/tmp/disk.bs of="$img" bs=1 skip=$off seek=$off count=16 \
			conv=notrunc 2>/dev/null
	done
	rm -f /tmp/disk.bs
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

	fingbox_keep_extra_partitions /tmp/image.bs "$disk"

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
