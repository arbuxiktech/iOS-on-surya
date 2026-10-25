# Surya bring-up

Surya is the Poco X3 NFC (`surya`, Qualcomm SM7150-AC / Snapdragon 732G). The working iOS port in this repository targets the Poco F1 (`beryllium`, SDM845). The repo now contains source-level Surya build and bring-up plumbing, but it does **not** produce a verified Surya iOS boot.

The repo now has Surya board selection in Enxerto, the Apple Device Tree generator, the XNU bring-up patches, Renegade's full-root boot helper, and Bergamota's builder and file-based build API. This remains a source-level port scaffold: it has not been built or booted on a Poco X3 NFC. The user-provided EEA V14.0.5.0.SJGEUXM ROM and a recovery-captured live FDT have been inspected. The live tree confirms the active DTBO index, Tianma panel, touchscreen configuration and physical memory banks; ABL acceptance and iOS hardware bring-up remain unverified.

## Upstream hardware facts used

The SM7150 mainline tree describes Surya and its shared components in [`sm7150-xiaomi-common.dtsi`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-common.dtsi) and [`sm7150-xiaomi-surya.dtsi`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-surya.dtsi):

- The framebuffer starts at `0x9c000000` and is 1080×2400; the shared DTS reserves exactly `1080 × 2400 × 4` bytes for it. A separate ramoops region starts at `0x9d800000`.
- The SoC uses the SM7150 family map already used by the legacy `sweet` profile, including the GIC, UFS host and 19.2 MHz timer.
- Surya uses six Kryo 470 Silver/A55 cores and two Kryo 470 Gold/A76 cores.
- The shared device tree uses PM6150 and PM6150L PMICs. The captured runtime tree identifies a Novatek `NVT-ts-spi` touchscreen on SPI CS0 at 8 MHz, with reset GPIO 8 and IRQ GPIO 9; its XNU driver is not ported.
- Surya has Huaxing and Tianma display panel variants in the upstream device-tree set. This phone's live tree identifies the Tianma NT36672C video panel. Use the extracted Xiaomi base DTB with the stock DTBO selection; the merged recovery FDT is for inspection and should not be substituted as the boot-image base.

## Upstream DTB references

I checked Xiaomi's official [`surya-q-oss` branch](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/surya-q-oss/arch/arm64/boot/dts/qcom) at commit `5e0a8dada006832d3c0511fdc7903c68474cad87`. It contains generic Atoll Qualcomm reference trees, but no Surya board DTS or prebuilt DTB. I therefore fetched and compiled the two panel-specific Surya DTS files from the SM7150 mainline tree: [`sm7150-xiaomi-surya-huaxing.dts`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-surya-huaxing.dts) and [`sm7150-xiaomi-surya-tianma.dts`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-surya-tianma.dts). Run `tools/build-surya-dtb.sh` to fetch the pinned source and rebuild both references.

The resulting files are in the ignored `dtb/surya/` directory:

| File | Model string | Size | SHA-256 |
| --- | --- | ---: | --- |
| `surya-huaxing.dtb` | Xiaomi POCO X3 NFC (Huaxing) | 96,426 bytes | `a43d069d0a49adcd3c6ba5e589940c91677c24f5a152d161ce1d1a5b6eb7a0dc` |
| `surya-tianma.dtb` | Xiaomi POCO X3 NFC (Tianma) | 96,418 bytes | `c7c7462fb7b12e9a5e9c4820f8368b376dc5d0c3fde787c75e0cd54e39b7cbbb` |

Both were compiled from Linux `v7.2`, commit `fd78d17954a86ea6ceb0c535e618ea129e09f8dd`, with `cpp` and `dtc` 1.7.0. Their root properties identify SM7150 (`qcom,msm-id = <0x16d 0>`) and board 34 (`qcom,board-id = <0x22 0>`). `dtc` emitted warnings from the upstream shared DTS about duplicate unit addresses and unnecessary address/size cells; it produced both blobs successfully.

These are mainline Linux source-derived reference DTBs, **not extracted Xiaomi stock DTBs**. Their SM7150 and board IDs match the phone's live FDT, but neither tree has been validated against ABL. Keep them for source comparison; use the extracted stock base DTB for an Enxerto boot image. The generated blobs and cloned source are ignored by git.

## Supplied Xiaomi stock ROM inspection

The supplied `V14.0.5.0.SJGEUXM` EEA fastboot ROM contains `boot.img` and `dtbo.img`; it has no separate `vendor_boot.img`. `tools/extract-dtb.py` found 16 FDT candidates in the Android v2 boot image:

- `rom-11.dtb` is the SM7150/SDMMAGPIE SoC tree (`qcom,msm-id = <0x16d 0>`, generic `qcom,board-id = <0 0>`). Its model is `Qualcomm Technologies, Inc. SDMMAGPIE SoC`; it has no Surya model, panel node or touchscreen node.
- `rom-12.dtb` is the SDMMAGPIEP variant (`qcom,msm-id = <0x16e 0>`), so it is not the SM7150 candidate for Surya.

The 32-entry `dtbo.img` contains Qualcomm IDP, QRD, ATP and RUMI board profiles. Android reports `ro.boot.dtbo_idx=16`, `ro.product.board=surya` and `ro.board.platform=sm6150`. The selected `rom-16.dtbo` is IDP/SDMMAGPIE (`qcom,msm-id = <0x16d 0>`, `qcom,board-id = <0x22 0>`); it contains both NT36672C panel definitions and a `novatek,NVT-ts-spi` touchscreen node.

The user RAM-booted OrangeFox recovery with `fastboot boot` (no partition was flashed), read `/sys/firmware/fdt`, and pulled a valid 604,053-byte merged FDT. It reports model `IDP`, the same SoC and board IDs, and selects the Tianma NT36672C FHD video panel. Its Novatek touchscreen node uses SPI CS0 at 8 MHz, reset GPIO 8 and IRQ GPIO 9. The live FDT contains two adjacent RAM banks: `<0x80000000 0x80000000>` and `<0x100000000 0xfcc00000>`. The fixed splash/framebuffer, ramoops and Qualcomm reservations are in the low bank. The XNU ADT profile therefore assigns kernel-managed RAM to the verified upper bank at `0x100000000:0xfcc00000`, leaving low-bank carve-outs outside XNU's allocator.

The stock boot image's `rom-11.dtb` is the unique SM7150 base candidate. It has generic board ID `<0 0>`; the merged live tree has board ID `<0x22 0>` after the board overlay. `tools/extract-dtb.py --live` now handles this case by selecting the unique SoC candidate and printing a warning. The extractor populated ignored `dtb/surya/dtb` with this stock base DTB. Keep the stock DTBO entry 16 available for the board-specific merged nodes, and validate ABL's handling with a RAM-boot before relying on the overlay for Enxerto. Do not package the already-merged `live.dtb` as the base, or substitute either mainline reference DTB. The ROM, `live.dtb` and extracted binary blobs stay ignored and are not committed; `/chosen/bootargs` in the live dump contains device-specific identifiers.

The community [Surya Android device configuration](https://github.com/koz-nik/android_device_xiaomi_surya/blob/cdf583c773203a13a6b15a544dcaeea0e18f95fc/BoardConfig.mk) selects boot image header v2 and has unsuffixed `boot` and `userdata` fstab entries. The supplied stock image confirms v2 and matches Enxerto's load offsets: page size 4096, kernel `0x8000`, ramdisk `0x1000000`, tags `0x100` and DTB `0x1f00000`. Its obsolete boot-header OS field encodes `11.0.0` and patch level `2023-06`, now mirrored by Enxerto; this field does not identify the installed Android release. See the [AOSP boot image header reference](https://source.android.com/docs/core/architecture/bootloader/boot-image-header) and [AOSP version-field note](https://source.android.com/docs/core/architecture/bootloader/version-info-avb).

## What this change covers

- `BOARD=surya` builds Enxerto with the SM7150 framebuffer geometry and IMEM restart address, and packages the extracted stock base DTB in an Android v2 boot image. ABL applying stock DTBO entry 16 to a custom fastboot boot image remains to be verified.
- Enxerto's early charger writes and off-mode charging screen are disabled for Surya. The existing screen and charger code targets the Poco F1 PMI8998 register map.
- `tools/mkadt.py --board surya` emits an iOS ADT with Surya and SM7150 identity, the current SweetPlatformExpert compatibility alias, six little cores and two big cores. Its default memory window is the live-FDT-confirmed upper bank, `0x100000000:0xfcc00000`, leaving fixed low-bank carve-outs outside XNU's allocator. `--highmem` selects that upper bank explicitly; `--memory BASE:SIZE` accepts a 16 KiB-aligned contiguous override. Managing both discontiguous banks would require additional ADT work.
- XNU patch 0251 recognizes Surya and skips the older I2C touchscreen probe. The Surya Novatek `nt36xxx` SPI driver is not ported yet.
- XNU's existing read-only PM6150L GPIO2 volume-up and PM6150 PON key path stays enabled. The existing PM6150 voltage-derived battery estimate is also enabled read-only; it is not calibrated for Surya and Enxerto charger writes/off-mode charging remain disabled.
- Bergamota's Build pane and file-based build request accept a target board and a stock/Huaxing/Tianma DTB choice. The Surya preset starts with one CPU, leaves the kernel console visible, enables the inherited SM7150 USB path for logs/control and the existing volume-key/read-only battery paths, and disables unported touch, GPU and radio paths.

The `sweet` compatibility alias is needed so the existing SM7150 kernel platform code can identify the custom `sweet-io` node. It does not make the Redmi Note 10 Pro's peripheral configuration valid for Surya. The inherited SM7150 USB, volume-key and read-only PM6150 battery paths are still unverified on Surya.

## Collecting device-specific input

Keep all device dumps in the ignored `backup/` and `dtb/` directories; do not commit them.

Use the supplied firmware images to extract the stock base DTB and overlays. Passing the live FDT lets the extractor select the unique matching SoC base candidate despite its generic board ID:

~~~sh
ROM=/path/to/surya_eea_global_images.../images
python3 tools/extract-dtb.py "$ROM/boot.img" dtb/surya --live dtb/surya/live.dtb
python3 tools/extract-dtbo.py "$ROM/dtbo.img" dtb/surya/stock-dtbo
~~~

The non-rooted stock Android shell denied access to `/sys/firmware/fdt` and `/proc/cmdline`; the first attempted capture was empty. A valid capture was then obtained from a temporarily RAM-booted OrangeFox recovery (the recovery was not flashed):

~~~sh
adb shell "cat /sys/firmware/fdt > /tmp/surya-live.dtb"
adb pull /tmp/surya-live.dtb dtb/surya/live.dtb
adb shell getprop ro.boot.dtbo_idx
~~~

The resulting FDT was 604,053 bytes. The binary remains under ignored `dtb/`; do not commit it because its `/chosen/bootargs` includes device-specific identifiers. The merged tree confirms the selected Tianma panel and board overlay; the memory and touch details are recorded above.

## Building the groundwork images

```sh
python3 tools/mkadt.py enxerto/out/surya-hi-3x.adt --board surya --display-scale 3 --points 360x800
cd enxerto
BOARD=surya DTB=../dtb/surya/dtb ./build.sh
```

The generated reference DTBs can also be selected explicitly with `SURYA_DTB_VARIANT=huaxing` or `tianma`; those Linux trees are for source comparison and are not stock Xiaomi boot DTBs. The default Surya ADT now uses the confirmed upper RAM bank; `--memory BASE:SIZE` remains available for a different verified contiguous region.

The command above expects the extracted stock base DTB at `dtb/surya/dtb`; the mainline reference trees and merged recovery FDT are not substitutes. The generated `enxerto-boot.img` is a bring-up artifact. Only RAM-boot it from ABL fastboot with `fastboot boot`; do not flash it to `boot`. No Enxerto image has been built or booted on Surya, so ABL's overlay behavior with this custom image is not yet confirmed. The separate `bergamota-fastboot.img` is built for development, but its partition access has not been checked on Surya either. Bergamota's board selection applies to image builds only; automatic phone identification and device-specific partition operations remain unverified.

## Work still needed

1. Build Enxerto and its Surya ADT; RAM-boot with the stock DTBO still present and confirm ABL passes the merged IDP/Tianma/touch tree. No iOS boot has been attempted yet.
2. Bring up XNU's Tianma display path and backlight; verify framebuffer handoff and brightness control. Add Huaxing support if needed for other Surya units.
3. Port the Novatek SPI touchscreen using the captured CS0/8 MHz/GPIO8 reset/GPIO9 IRQ configuration. Verify the inherited PM6150L GPIO2/PM6150 PON key path and read-only battery estimate on hardware; keep charger writes off until mapped against Surya's own device tree.
4. Bring up the Adreno 618, WLAN/Bluetooth, modem, audio, cameras, sensors and NFC; these are not covered by the Poco F1 drivers.
5. Confirm Surya's actual GPT and validate Renegade/root and Bergamota device operations against its partition and USB identities. Keep device changes temporary until the RAM-boot and driver paths are verified.

Until those steps are complete, this is a source-level bring-up scaffold rather than a usable Surya port.
