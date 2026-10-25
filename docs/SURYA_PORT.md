# Surya bring-up

Surya is the Poco X3 NFC (`surya`, Qualcomm SM7150-AC / Snapdragon 732G). The working iOS port in this repository targets the Poco F1 (`beryllium`, SDM845). The repo now contains source-level Surya build and bring-up plumbing, but it does **not** produce a verified Surya iOS boot.

The repo now has Surya board selection in Enxerto, the Apple Device Tree generator, the XNU bring-up patches, Renegade's full-root boot helper, and Bergamota's builder and file-based build API. This is a source-level port scaffold; it has not been built or booted on a Poco X3 NFC. The user-provided EEA V14.0.5.0.SJGEUXM ROM has been inspected, and Android reports `ro.boot.dtbo_idx=16`, confirming the selected overlay. A live `/sys/firmware/fdt` is still needed to inspect the merged tree, memory map and this phone's panel.

## Upstream hardware facts used

The SM7150 mainline tree describes Surya and its shared components in [`sm7150-xiaomi-common.dtsi`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-common.dtsi) and [`sm7150-xiaomi-surya.dtsi`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-surya.dtsi):

- The framebuffer starts at `0x9c000000` and is 1080×2400; the shared DTS reserves exactly `1080 × 2400 × 4` bytes for it. A separate ramoops region starts at `0x9d800000`.
- The SoC uses the SM7150 family map already used by the legacy `sweet` profile, including the GIC, UFS host and 19.2 MHz timer.
- Surya uses six Kryo 470 Silver/A55 cores and two Kryo 470 Gold/A76 cores.
- The shared device tree uses PM6150 and PM6150L PMICs. Surya enables a Novatek `nt36xxx` touchscreen over SPI; the exact panel/controller variant should be checked against the phone's live tree.
- Surya has Huaxing and Tianma display panel variants in the upstream device-tree set. The stock device tree for the user's phone must be retained in the Android boot image.

## Upstream DTB references

I checked Xiaomi's official [`surya-q-oss` branch](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/surya-q-oss/arch/arm64/boot/dts/qcom) at commit `5e0a8dada006832d3c0511fdc7903c68474cad87`. It contains generic Atoll Qualcomm reference trees, but no Surya board DTS or prebuilt DTB. I therefore fetched and compiled the two panel-specific Surya DTS files from the SM7150 mainline tree: [`sm7150-xiaomi-surya-huaxing.dts`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-surya-huaxing.dts) and [`sm7150-xiaomi-surya-tianma.dts`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-surya-tianma.dts). Run `tools/build-surya-dtb.sh` to fetch the pinned source and rebuild both references.

The resulting files are in the ignored `dtb/surya/` directory:

| File | Model string | Size | SHA-256 |
| --- | --- | ---: | --- |
| `surya-huaxing.dtb` | Xiaomi POCO X3 NFC (Huaxing) | 96,426 bytes | `a43d069d0a49adcd3c6ba5e589940c91677c24f5a152d161ce1d1a5b6eb7a0dc` |
| `surya-tianma.dtb` | Xiaomi POCO X3 NFC (Tianma) | 96,418 bytes | `c7c7462fb7b12e9a5e9c4820f8368b376dc5d0c3fde787c75e0cd54e39b7cbbb` |

Both were compiled from Linux `v7.2`, commit `fd78d17954a86ea6ceb0c535e618ea129e09f8dd`, with `cpp` and `dtc` 1.7.0. Their root properties identify SM7150 (`qcom,msm-id = <0x16d 0>`) and board 34 (`qcom,board-id = <0x22 0>`). `dtc` emitted warnings from the upstream shared DTS about duplicate unit addresses and unnecessary address/size cells; it produced both blobs successfully.

These are mainline Linux source-derived reference DTBs, **not extracted Xiaomi stock DTBs**. Their SM7150 and board IDs match the candidate IDs found in this ROM, but the phone's active overlay and panel variant are unknown, and neither tree has been validated against ABL or the live FDT. Keep them for source comparison; use a confirmed device tree for an Enxerto boot image. The generated blobs and cloned source are ignored by git.

## Supplied Xiaomi stock ROM inspection

The supplied `V14.0.5.0.SJGEUXM` EEA fastboot ROM contains `boot.img` and `dtbo.img`; it has no separate `vendor_boot.img`. `tools/extract-dtb.py` found 16 FDT candidates in the Android v2 boot image:

- `rom-11.dtb` is the SM7150/SDMMAGPIE SoC tree (`qcom,msm-id = <0x16d 0>`, generic `qcom,board-id = <0 0>`). Its model is `Qualcomm Technologies, Inc. SDMMAGPIE SoC`; it has no Surya model, panel node or touchscreen node.
- `rom-12.dtb` is the SDMMAGPIEP variant (`qcom,msm-id = <0x16e 0>`), so it is not the SM7150 candidate for Surya.

The 32-entry `dtbo.img` contains Qualcomm IDP, QRD, ATP and RUMI board profiles. The user reports `ro.boot.dtbo_idx=16`, confirming that `rom-16.dtbo` is selected. Its root says `IDP` / `qcom,sdmmagpie-idp`, with `qcom,msm-id = <0x16d 0>` and `qcom,board-id = <0x22 0>`, matching the upstream Surya DTS. It includes both NT36672C Huaxing and Tianma panel definitions and a `novatek,NVT-ts-spi` touchscreen node. Android also reports `ro.product.board=surya` and `ro.board.platform=sm6150`. The active overlay still does not identify which panel is installed; a live FDT is needed to inspect the merged device tree.

The extracted stock candidates are local-only under ignored `dtb/surya/rom-*.dtb` and `dtb/surya/stock-dtbo/`; neither the ROM nor its extracted binary blobs are committed. The extractor for Android DT table overlays is `tools/extract-dtbo.py`. The current `dtb/surya/dtb` expected by Enxerto is intentionally not populated with generic `rom-11.dtb`.

The community [Surya Android device configuration](https://github.com/koz-nik/android_device_xiaomi_surya/blob/cdf583c773203a13a6b15a544dcaeea0e18f95fc/BoardConfig.mk) selects boot image header v2 and has unsuffixed `boot` and `userdata` fstab entries. The supplied stock image confirms v2 and matches Enxerto's load offsets: page size 4096, kernel `0x8000`, ramdisk `0x1000000`, tags `0x100` and DTB `0x1f00000`. Its obsolete boot-header OS field encodes `11.0.0` and patch level `2023-06`, now mirrored by Enxerto; this field does not identify the installed Android release. See the [AOSP boot image header reference](https://source.android.com/docs/core/architecture/bootloader/boot-image-header) and [AOSP version-field note](https://source.android.com/docs/core/architecture/bootloader/version-info-avb).

## What this change covers

- `BOARD=surya` builds Enxerto with the SM7150 framebuffer geometry and IMEM restart address, and packages the phone's DTB in an Android v2 boot image.
- Enxerto's early charger writes and off-mode charging screen are disabled for Surya. The existing screen and charger code targets the Poco F1 PMI8998 register map.
- `tools/mkadt.py --board surya` emits an iOS ADT with Surya and SM7150 identity, the current SweetPlatformExpert compatibility alias, six little cores and two big cores. Its default kernel memory window reuses the existing `sweet` low-memory range below 4 GiB; this is an assumption. `--memory BASE:SIZE` accepts one 16 KiB-aligned contiguous range from a verified live FDT; discontiguous banks need additional ADT work.
- XNU patch 0251 recognizes Surya and skips the older I2C touchscreen probe. The Surya Novatek `nt36xxx` SPI driver is not ported yet.
- XNU's existing read-only PM6150L GPIO2 volume-up and PM6150 PON key path stays enabled. The existing PM6150 voltage-derived battery estimate is also enabled read-only; it is not calibrated for Surya and Enxerto charger writes/off-mode charging remain disabled.
- Bergamota's Build pane and file-based build request accept a target board and a stock/Huaxing/Tianma DTB choice. The Surya preset starts with one CPU, leaves the kernel console visible, enables the inherited SM7150 USB path for logs/control and the existing volume-key/read-only battery paths, and disables unported touch, GPU and radio paths.

The `sweet` compatibility alias is needed so the existing SM7150 kernel platform code can identify the custom `sweet-io` node. It does not make the Redmi Note 10 Pro's peripheral configuration valid for Surya. The inherited SM7150 USB, volume-key and read-only PM6150 battery paths are still unverified on Surya.

## Collecting device-specific input

Keep all device dumps in the ignored `backup/` and `dtb/` directories; do not commit them.

Use the supplied firmware images to extract the candidates:

~~~sh
ROM=/path/to/surya_eea_global_images.../images
python3 tools/extract-dtb.py "$ROM/boot.img" dtb/surya
python3 tools/extract-dtbo.py "$ROM/dtbo.img" dtb/surya/stock-dtbo
~~~

To try the live FDT from stock Android, write it under Android's temporary-data directory, then pull it to the host:

~~~sh
adb shell "cat /sys/firmware/fdt > /data/local/tmp/surya-live.dtb"
adb pull /data/local/tmp/surya-live.dtb backup/surya-live.dtb
adb shell getprop ro.boot.dtbo_idx
~~~

A non-rooted stock shell may be denied access to `/sys/firmware/fdt`; this phone also denies `/proc/cmdline`. If the FDT read fails, use a trusted recovery shell, where root can copy it to `/tmp/surya-live.dtb` before pulling it. `/tmp` is not present on this stock Android shell. Check the live tree's model, SoC and board IDs, memory nodes, reserved-memory regions, panel and touchscreen before selecting a DTB for Enxerto. `extract-dtb.py --live` can compare live IDs with boot candidates; this ROM's generic SDMMAGPIE base ID may not match a post-overlay live tree, so review an unmatched result rather than forcing a selection.

## Building the groundwork images

```sh
python3 tools/mkadt.py enxerto/out/surya-hi-3x.adt --board surya --display-scale 3 --points 360x800
cd enxerto
BOARD=surya DTB=../dtb/surya/dtb ./build.sh
```

The generated reference DTBs can also be selected explicitly with `SURYA_DTB_VARIANT=huaxing` or `tianma`; those Linux trees are for source comparison and are not stock Xiaomi boot DTBs. If a live FDT provides verified physical memory, pass it to the ADT generator as `--memory BASE:SIZE`.

The command above expects the phone's extracted stock DTB at `dtb/surya/dtb`; the two mainline reference DTBs above are not substitutes for it. The generated `enxerto-boot.img` is a bring-up artifact. Only RAM-boot it from ABL fastboot with `fastboot boot`; do not flash it to `boot`. No Surya device has been attached or booted in this task, and the app warns about this status. The separate `bergamota-fastboot.img` is built for development, but its partition access has not been checked on Surya either. Bergamota's board selection applies to image builds only; automatic phone identification and device-specific partition operations remain unverified.

## Work still needed

1. Capture the runtime FDT and confirm the live board ID, assumed `0xb0000000..0xfd000000` kernel memory window and panel variant from an actual Surya. The selected DTBO entry is confirmed as 16.
2. Bring up XNU's display path and backlight for both panel vendors; verify framebuffer handoff and brightness control.
3. Port the Novatek `nt36xxx` SPI touchscreen. Verify the inherited PM6150L GPIO2/PM6150 PON key path and read-only battery estimate on hardware; keep charger writes off until mapped against Surya's own device tree.
4. Bring up the Adreno 618, WLAN/Bluetooth, modem, audio, cameras, sensors and NFC; these are not covered by the Poco F1 drivers.
5. Confirm Surya's actual GPT and validate Renegade/root and Bergamota device operations against its partition and USB identities, then perform a RAM-boot test before considering any persistent change.

Until those steps are complete, this is a source-level bring-up scaffold rather than a usable Surya port.
