# Surya bring-up

Surya is the Poco X3 NFC (`surya`, Qualcomm SM7150-AC / Snapdragon 732G). The working iOS port in this repository targets the Poco F1 (`beryllium`, SDM845). The repo now contains source-level Surya build and bring-up plumbing, but it does **not** produce a verified Surya iOS boot.

The repo now has Surya board selection in Enxerto, the Apple Device Tree generator, XNU bring-up patches, Renegade's full-root boot helper, and Bergamota's builder and file-based build API. This remains a source-level port scaffold: it has not been built or booted on a Poco X3 NFC. The user-provided EEA V14.0.5.0.SJGEUXM ROM and a recovery-captured live FDT have been inspected. The live tree confirms the active DTBO index, Tianma panel, touchscreen configuration and physical memory banks; ABL acceptance and iOS hardware bring-up remain unverified.

## Upstream hardware facts used

The SM7150 mainline tree describes Surya and its shared components in [`sm7150-xiaomi-common.dtsi`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-common.dtsi) and [`sm7150-xiaomi-surya.dtsi`](https://github.com/sm7150-mainline/linux/blob/v7.2/arch/arm64/boot/dts/qcom/sm7150-xiaomi-surya.dtsi):

- The framebuffer starts at `0x9c000000` and is 1080×2400; the shared DTS reserves exactly `1080 × 2400 × 4` bytes for it. A separate ramoops region starts at `0x9d800000`.
- The SoC uses the SM7150 family map already used by the legacy `sweet` profile, including the GIC, UFS host and 19.2 MHz timer.
- Surya uses six Kryo 470 Silver/A55 cores and two Kryo 470 Gold/A76 cores.
- The shared device tree uses PM6150 and PM6150L PMICs. The captured runtime tree identifies a Novatek `NVT-ts-spi` touchscreen on SPI CS0 at 8 MHz, with reset GPIO 8 and IRQ GPIO 9. XNU patch 0253 contains an opt-in QUP0 GENI SPI and host-download source path; it uses GPIO8 for reset and configures GPIO9, but polls reports instead of using IRQ. It is not compiled or hardware-verified.
- Surya has Huaxing and Tianma display panel variants in the upstream device-tree set. This phone's live tree identifies the Tianma NT36672C video panel. Use the extracted Xiaomi base DTB with the stock DTBO selection; the merged recovery FDT is for inspection and should not be substituted as the boot-image base.
- The live tree exposes a `qcom,pm6150l-spmi-wled` block on PMIC SID 5 (`0xd800` control, `0xd900` sink). This is WLED5: patch 0252 adds a Surya-only module A/B brightness, width and sync backend to the existing XNU backlight path. It is opt-in through the existing backlight boot flag and is not built or hardware-verified. The existing F1-only PMI8998 WLED4 path remains Beryllium-specific. The WLED5 register definitions and update order follow the pinned [SM7150 mainline WLED driver](https://github.com/sm7150-mainline/linux/blob/v7.2/drivers/video/backlight/qcom-wled.c).

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
- XNU patches 0251, 0253 and 0258 select an experimental Surya-only Novatek path: QUP0 SE0 GENI FIFO SPI, the 3.0 V L18A rail, GPIO8 reset sequencing, trim-ID validation, optional Xiaomi-format firmware download to volatile SRAM, and polled 10-finger reports. It remains off by default. The exact Tianma firmware extracted from the supplied stock ROM is `dtb/surya/firmware/touch/novatek_ts_tianma_fw.bin`; it is ignored and must not be committed. `sweettouch=1 sweettouchstage=1..5` selects stages; stages 4-5 require the prior probe logs to be reviewed, and stage 5 also requires an ADT `/sweet-touch/firmware` property plus `sweettouchfw=1`. Reset GPIO8 is used; IRQ GPIO9 is configured as input but reports are polled. Contact events are delivered through the shared `SweetHIDTouch` IOHID event service to BackBoard. No build or hardware touch test has been done.
- XNU patch 0252 adds a Surya-only PM6150L WLED5 brightness backend. It detects the active WLED module and width, preserves unrelated register bits, and remains opt-in. This is a source port only; the kernel series has not been built and the backlight has not been exercised on the phone.
- XNU patch 0255 adapts the IORTC wall-clock path to the live PM6150 RTC at SID 0 (`0x6000` RTC and `0x6100` alarm). It follows the standard PM8941-compatible register layout used by upstream Linux, reads the RTC and writes an offset in alarm data only when the alarm is disabled; SPMI writes still require AP ownership. This is source-only and unverified.
- XNU patch 0254 adapts the shared PS_HOLD reset path and the IMEM restart-reason word to the addresses in the captured Surya FDT. The PM6150 reboot-reason write is deliberately not reused from Beryllium; reboot mode handling is source-only and hardware-unverified.
- XNU patch 0256 adds an off-by-default Surya cpufreq-hw path using the upstream SM7150 domain addresses and CPU OPP lists. `sweetcpufreq=1` reads both LUTs without changing state; `sweetcpufreq=2` selects the highest listed OPP. This relies on upstream SoC data, has not been built or exercised, and does not add runtime frequency scaling.
- XNU's existing read-only PM6150L GPIO2 volume-up and PM6150 PON key path stays enabled. The existing PM6150 voltage-derived battery estimate is also enabled read-only; it is not calibrated for Surya and Enxerto charger writes/off-mode charging remain disabled.
- Bergamota's Build pane and file-based build request accept a target board and a stock/Huaxing/Tianma DTB choice. The Surya preset starts with one CPU, leaves the kernel console visible, enables the inherited SM7150 USB path for logs/control and the existing volume-key/read-only battery paths, and leaves experimental touch/GPU and radio paths off by default.

The `sweet` compatibility alias is needed so the existing SM7150 kernel platform code can identify the custom `sweet-io` node. It does not make the Redmi Note 10 Pro's peripheral configuration valid for Surya. The inherited SM7150 USB, volume-key and read-only PM6150 battery paths are still unverified on Surya.

## Driver port status

“Ported” here means source was adapted to Surya's board data; no Surya kernel build or iOS hardware boot has been done. Shared SoC code is not considered hardware-verified just because the phone also uses SM7150.

| Subsystem | Surya source status | Remaining work |
| --- | --- | --- |
| Boot, ADT, memory and Enxerto profile | Board-specific source plumbing exists | Build and RAM-boot with stock DTBO entry 16; verify ABL handoff and the XNU memory window |
| Framebuffer / Tianma panel | Existing ABL framebuffer handoff and 1080×2400 canvas are reused | Verify framebuffer ownership and iOS display geometry on Surya; no panel initialization driver has been brought up |
| PM6150L WLED5 backlight | Source backend added in XNU patch 0252; opt-in only | Build and verify SID 5 reads/writes and brightness on hardware |
| Novatek NT36672C touch | Experimental staged QUP0 GENI FIFO SPI, L18A rail, GPIO8 reset, Xiaomi firmware download and polled 10-finger reports in patch 0253; opt-in rail allowlist in 0258 | Build; review stage logs in order, confirm trim ID and firmware startup, then verify IRQ behavior, coordinate mapping, event delivery and panel/touch timing; firmware stays outside Git |
| UFS storage | Existing SM7150/Sweet UFS implementation is reused | Confirm controller state, DMA addressability and root-partition mapping on Surya |
| USB | Existing SM7150 DWC3 path is reused by the Surya preset | Confirm PHY, SMMU and fastboot/ADB behavior on the phone |
| Keys and battery | Existing PM6150/PON read paths are reused read-only | Confirm actual key GPIO/PON wiring and calibrate the voltage-based battery estimate |
| Charger / off-mode charging | Disabled for Surya | Map Surya's PM6150L/SMB5 registers and safety behavior before enabling any write |
| GPU | Patch 0259 adds staged Adreno 618 GMU/SMMU/HFI startup, low-level GX power, and signed `a615_zap` PAS handling on top of 0257's read-only probe; opt-in stages 1–6 | Build; run and review each stage in sequence on Surya; CP command submission and userspace rendering are not implemented |
| Wi-Fi / Bluetooth | Existing WCN3990 bring-up is Beryllium-gated; Surya radio support is disabled | Identify the Surya radio configuration and port its power, firmware, transport and iOS interfaces |
| Modem, audio, cameras, sensors and NFC | Not ported | Identify each live-FDT device and implement its bus, power, firmware and userland interfaces |
| Reboot / reset | Patch 0254 maps Surya PS_HOLD (`0x0c264000`) and IMEM (`0x146aa000`, `restart_reason@0x65c`) from the live FDT; Surya skips Beryllium PM8998 PON writes | Compile and verify normal reset and bootloader/recovery/Bergamota reasons on hardware; map PM6150 PON restart-reason handling before enabling writes |
| RTC / wall clock | Patch 0255 adapts the PM6150 SID 0 RTC/alarm path and only stores its wall-clock offset while the alarm is disabled | Confirm AP read/write ownership, persisted time and alarm behavior on hardware; no build or RTC test has been done |
| CPU frequency | Patch 0256 adds an off-by-default SM7150 cpufreq-hw probe and opt-in max OPP selection, with exact upstream A55/A76 OPP allowlists | Build; inspect both LUTs with `sweetcpufreq=1`, then separately validate `sweetcpufreq=2` and thermal behavior; runtime scaling is not implemented |
| Renegade and Bergamota | Board selection and build plumbing exist | Validate Surya GPT/partition and USB identities, then exercise each operation on the device |

### Touch and graphics userland

The physical touch path already ends at the kernel's `SweetHIDTouch` digitizer service, which publishes normalized events for BackBoard. No separate Surya app-side touch driver is required. The `sweettouch` SSH helper is synthetic event injection for userland checks; it now accepts `--size 360x800` to match the Surya ADT point geometry. It does not verify the SPI controller or physical touch panel. The iOS 16 `tools/sweetnet/build.sh` output now includes this helper, and the existing iOS 18 arm64e output still builds it.

The EAGL/Mesa userland bridge now has a native arm64 build configuration, and its libdrm stand-in probes the planned `SweetAdreno618` service as well as the existing A630 service. See `docs/GPU_EAGL.md` for the payload command. Since Surya's XNU does not yet publish that user client or submit GPU commands, current Surya boots will take the Mesa softpipe fallback. Hardware acceleration remains blocked on the kernel user client and CP path.

For the synthetic input helper on the iOS 16 userland, build with `TOOLS=sweettouch IOS18=0 tools/sweetnet/build.sh`; the Surya point-space command is `sweettouch --size 360x800 tap 180 400`. On iOS 18, the same helper is included in `tools/sweetnet/build.sh`'s `ios18/` output. This confirms only HID event injection and coordinate scaling; verify physical touch by checking that Surya SPI reports reach the screen through `SweetHIDTouch`.

### Adreno 618 staged bring-up

The live tree and pinned SM7150 DTS identify `qcom,adreno-618.0`, GPU core `0x05000000`, GMU `0x0506a000`, GPUCC `0x05090000`, Adreno SMMU `0x05040000`, and the GMU PDC windows at `0x0b290000` / `0x0b490000`. Patch 0257 supplies stage 1's read-only gate report. Patch 0259 adds opt-in stages 2–6: CX/GMU clocks and a TCM check; cold boot from stock `a618_gmu.bin`; GMU SMMU/HFI setup; GX power capped to the common 180 MHz MIN_SVS level with the A618 HFI bandwidth table; and signed `a615_zap` PAS authentication using the live-FDT carveout at `0x97715000`. It uses the SM7150 cmd-db at `0x85f20000`. `tools/adt-gpufw.py --board surya` packages the GMU, shared SQE and signed ZAP firmware into `/sweet-gpu`; the current stages do not start the SQE or command processor.

To place the local stock GPU firmware in an ADT, start with the Surya ADT and run:

```sh
python3 tools/adt-gpufw.py enxerto/out/surya-touch.adt enxerto/out/surya-gpu.adt --board surya --fw dtb/surya/firmware/gpu --zap dtb/surya/firmware/gpu
```

This embeds Qualcomm firmware bytes in the generated ADT; keep the ADT and extracted firmware out of Git.

The Beryllium Adreno 630 driver remains board-gated. Surya's staged path is source-only: it has not been built or hardware-verified. It stops before CP command submission, so it does not provide rendering, Metal, CoreAnimation or userspace GPU acceleration. Keep `sweetgpu` unset except during controlled stage-by-stage bring-up; a Surya device is needed to confirm clock/power sequences, firmware startup, PAS authentication and cleanup.

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

To add the local Tianma touch firmware to a Surya ADT, pass its ignored file explicitly:

```sh
python3 tools/mkadt.py enxerto/out/surya-touch.adt --board surya --touch-fw dtb/surya/firmware/touch/novatek_ts_tianma_fw.bin
```

The firmware file is extracted from the supplied Xiaomi ROM and stays ignored under `dtb/surya/firmware/touch/`. This command embeds it in the ADT; it does not enable touch. Bring the path up in order with `sweettouch=1 sweettouchstage=N`: stage 1 reads TLMM, stage 2 reads SE/GCC, stage 3 enables QUP0 and configures the pads and L18A rail, stage 4 applies the GPIO8/software-reset sequence and reads the trim ID, and stage 5 additionally requires `sweettouchfw=1` to download firmware to volatile SRAM and poll reports. GPIO9 is configured but no IRQ handler is installed. Review each previous-stage log before advancing.

The generated reference DTBs can also be selected explicitly with `SURYA_DTB_VARIANT=huaxing` or `tianma`; those Linux trees are for source comparison and are not stock Xiaomi boot DTBs. The default Surya ADT now uses the confirmed upper RAM bank; `--memory BASE:SIZE` remains available for a different verified contiguous region.

The command above expects the extracted stock base DTB at `dtb/surya/dtb`; the mainline reference trees and merged recovery FDT are not substitutes. The generated `enxerto-boot.img` is a bring-up artifact. Only RAM-boot it from ABL fastboot with `fastboot boot`; do not flash it to `boot`. No Enxerto image has been built or booted on Surya, so ABL's overlay behavior with this custom image is not yet confirmed. The separate `bergamota-fastboot.img` is built for development, but its partition access has not been checked on Surya either. Bergamota's board selection applies to image builds only; automatic phone identification and device-specific partition operations remain unverified.

## Work still needed

1. Build Enxerto and its Surya ADT; RAM-boot with stock DTBO entry 16 and confirm ABL passes the merged IDP/Tianma/touch tree. No iOS boot has been attempted yet.
2. Verify the WLED5 backend and framebuffer handoff on the live panel. Bring up the Novatek path stage by stage; the source currently polls SPI reports instead of using IRQ GPIO9, so verify firmware startup, reset timing, coordinate mapping and touch events on hardware.
3. Verify UFS, USB, PM6150/PON keys and the read-only battery estimate. Keep charger writes off until their registers and safety behavior are mapped for Surya.
4. Build and validate the staged Adreno 618 path before continuing with WLAN/Bluetooth, modem, audio, cameras, sensors and NFC. Reboot, RTC and a limited CPU-frequency max-state path have source adaptations but remain unverified. This remains far from a complete device driver port.
5. Confirm Surya's actual GPT and validate Renegade/root and Bergamota device operations against its partition and USB identities. Keep device changes temporary until the RAM-boot and driver paths are verified.

Until those steps are complete, this is a source-level bring-up scaffold rather than a usable Surya port.
