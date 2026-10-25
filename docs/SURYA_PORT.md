# Surya bring-up

Surya is the Poco X3 NFC (`surya`, Qualcomm SM7150-AC / Snapdragon 732G). This repository's working iOS port targets the Poco F1 (`beryllium`, SDM845). This change adds an experimental Enxerto and Apple Device Tree profile and makes the Bergamota builder select it. It does **not** produce a verified Surya iOS boot.

The profile uses upstream SM7150 device-tree facts for now, as requested. A stock Surya boot image or live `/sys/firmware/fdt` is still needed to verify the boot header parameters, board IDs, memory map and the particular phone's display panel.

## Upstream hardware facts used

The SM7150 mainline tree describes Surya and its shared components in [`sm7150-xiaomi-common.dtsi`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-common.dtsi) and [`sm7150-xiaomi-surya.dtsi`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-surya.dtsi):

- The framebuffer starts at `0x9c000000` and is 1080×2400; the shared DTS reserves exactly `1080 × 2400 × 4` bytes for it. A separate ramoops region starts at `0x9d800000`.
- The SoC uses the SM7150 family map already used by the legacy `sweet` profile, including the GIC, UFS host and 19.2 MHz timer.
- Surya uses six Kryo 470 Silver/A55 cores and two Kryo 470 Gold/A76 cores.
- The shared device tree uses PM6150 and PM6150L PMICs. Surya enables a Novatek `nt36xxx` touchscreen over SPI; the exact panel/controller variant should be checked against the phone's live tree.
- Surya has Huaxing and Tianma display panel variants in the upstream device-tree set. The stock device tree for the user's phone must be retained in the Android boot image.

Android 10 launch devices use boot image header version 2, which is the format the Surya Enxerto profile emits. Its OS version and patch-level fields are launch-era placeholders until the stock image is read. See the [AOSP boot image header reference](https://source.android.com/docs/core/architecture/bootloader/boot-image-header).

## What this change covers

- `BOARD=surya` builds Enxerto with the SM7150 framebuffer geometry and IMEM restart address, and packages the phone's DTB in an Android v2 boot image.
- Enxerto's early charger writes and off-mode charging screen are disabled for Surya. The existing screen and charger code targets the Poco F1 PMI8998 register map.
- `tools/mkadt.py --board surya` emits an iOS ADT with Surya and SM7150 identity, the current SweetPlatformExpert compatibility alias, six little cores and two big cores. Its initial kernel memory window reuses the existing `sweet` low-memory range below 4 GiB; that range is not confirmed by a Surya-specific memory map and must be checked before boot.
- XNU patch 0251 recognizes Surya and skips the older I2C touchscreen probe. The Surya Novatek `nt36xxx` SPI driver is not ported yet.
- Bergamota's Build pane and file-based build request accept a target board. The Surya preset starts with one CPU, leaves the kernel console visible, enables the inherited SM7150 USB path for logs/control, and disables the unported touch, battery, GPU and radio paths.

The `sweet` compatibility alias is needed so the existing SM7150 kernel platform code can identify the custom `sweet-io` node. It does not make the Redmi Note 10 Pro's peripheral configuration valid for Surya. The safe preset enables the existing SM7150 USB device path for bring-up access; this is still unverified on Surya.

## Collecting device-specific input

Keep all device dumps in the ignored `backup/` and `dtb/` directories; do not commit them.

```sh
adb pull /dev/block/by-name/boot backup/surya-boot.img
adb pull /sys/firmware/fdt backup/surya-live.dtb
python3 tools/extract-dtb.py backup/surya-boot.img dtb/surya --live backup/surya-live.dtb
```

If Android does not expose the live tree, pull the boot image and FDT from a trusted recovery with `adb root`. `extract-dtb.py` reads the v2 DTB section and uses the live tree's board IDs to choose the matching blob. Check the `model`, `qcom,msm-id`, `qcom,board-id`, memory nodes and reserved-memory regions before using it.

## Building the groundwork images

```sh
python3 tools/mkadt.py enxerto/out/surya-hi-3x.adt --board surya --display-scale 3 --points 360x800
cd enxerto
BOARD=surya DTB=../dtb/surya/dtb ./build.sh
```

The generated `enxerto-boot.img` is a bring-up artifact. Only RAM-boot it from ABL fastboot with `fastboot boot`; do not flash it to `boot`. No Surya device has been attached or booted in this task, and the app warns about this status. The separate `bergamota-fastboot.img` is built for development, but its partition access has not been checked on Surya either.

## Work still needed

1. Confirm the boot image v2 load offsets and metadata, the live FDT/board ID, the assumed `0xb0000000..0xfd000000` kernel memory window and panel variant from an actual Surya.
2. Bring up XNU's display path and backlight for both panel vendors; verify framebuffer handoff and brightness control.
3. Port the Novatek `nt36xxx` SPI touchscreen and Surya-specific key handling.
4. Port PM6150/PM6150L battery, charger and off-mode charging support. Keep register writes off until mapped against Surya's own device tree and checked on hardware.
5. Bring up the Adreno 618, WLAN/Bluetooth, modem, audio, cameras, sensors and NFC; these are not covered by the Poco F1 drivers.
6. Adapt Renegade/root installation and the Bergamota status/control plane for Surya partition names and hardware capabilities, then perform a RAM-boot test before considering any persistent change.

Until those steps are complete, this is a source-level bring-up scaffold rather than a usable Surya port.
