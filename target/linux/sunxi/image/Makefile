# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2013-2016 OpenWrt.org
# Copyright (C) 2016 Yousong Zhou

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

FAT32_BLOCK_SIZE=1024
FAT32_BLOCKS=$(shell echo $$(($(CONFIG_SUNXI_SD_BOOT_PARTSIZE)*1024*1024/$(FAT32_BLOCK_SIZE))))

DEVICE_VARS := SUNXI_DTS SUNXI_DTS_DIR SUNXI_BOOT_SCRIPT

define Build/sunxi-sdcard
	rm -f $@.boot
	mkfs.fat $@.boot -C $(FAT32_BLOCKS)

	mcopy -i $@.boot $(STAGING_DIR_IMAGE)/$(DEVICE_NAME)-boot.scr ::boot.scr
	mcopy -i $@.boot $(IMAGE_KERNEL) ::uImage
	./gen_sunxi_sdcard_img.sh $@ \
		$@.boot \
		$(IMAGE_ROOTFS) \
		$(CONFIG_SUNXI_SD_BOOT_PARTSIZE) \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) \
		$(STAGING_DIR_IMAGE)/$(DEVICE_NAME)-u-boot-with-spl.bin
	rm -f $@.boot
endef

# For devices that keep their vendor U-Boot: no bootloader in the image,
# a zImage and a separate DTB instead of a FIT image, and a boot script
# for the vendor U-Boot's distro boot.
define Build/sunxi-sdcard-vendor-uboot
	rm -f $@.boot $@.scr
	mkfs.fat $@.boot -C $(FAT32_BLOCKS)

	mkimage -C none -A arm -T script -d $(SUNXI_BOOT_SCRIPT) $@.scr
	mcopy -i $@.boot $@.scr ::boot.scr
	mcopy -i $@.boot $(IMAGE_KERNEL) ::zImage
	mcopy -i $@.boot $(DTS_DIR)/$(SUNXI_DTS).dtb ::dtb
	./gen_sunxi_sdcard_img.sh $@ \
		$@.boot \
		$(IMAGE_ROOTFS) \
		$(CONFIG_SUNXI_SD_BOOT_PARTSIZE) \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) \
		/dev/null
	rm -f $@.boot $@.scr
endef

define Build/sunxi-append-dtb
	cat $(DTS_DIR)/$(SUNXI_DTS).dtb >> $@
endef

# why \x00\x00\x00\x00 for zImage-initramfs
define Device/Default
  PROFILES := Default
  KERNEL_NAME := zImage
  KERNEL := kernel-bin | uImage none
  IMAGES := sdcard.img.gz
  IMAGE/sdcard.img.gz := sunxi-sdcard | append-metadata | gzip
  SUNXI_DTS_DIR := allwinner/
  SUNXI_DTS = $$(SUNXI_DTS_DIR)$$(SOC)-$(lastword $(subst _, ,$(1)))
endef

define Device/FitImageLzma
  KERNEL = kernel-bin | lzma | fit lzma $$(DTS_DIR)/$$(SUNXI_DTS).dtb
endef

define Device/FitImageGzip
  KERNEL = kernel-bin | gzip | fit gzip $$(DTS_DIR)/$$(SUNXI_DTS).dtb
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
