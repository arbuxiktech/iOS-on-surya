# XNU for sweet

Built on GitHub's macOS arm64 runners by `.github/workflows/xnu.yml`, using
[blacktop/darwin-xnu-build](https://github.com/blacktop/darwin-xnu-build) (MIT) at a pinned commit.

- `MACOS_VERSION=13.5` -> xnu-8796 (same generation as iOS 16.6/16.7, the last iOS for iPhone 8).
- `patches/*.patch` are copied into the build script's patch dir and applied to the xnu tree with `git apply`.
- Output: `kernel.<config>.vmapple` (later: our own SWEET machine config) as a workflow artifact.

The current iOS 18 series lives in `patches-11215/`. The Surya bring-up command line enables shared SM7150 USB, PM6150L key and read-only PM6150 battery paths. Patches 0251 and 0253 select an experimental, staged Surya Novatek SPI path; it is off by default and has not been compiled or hardware-verified. Patch 0252 adds the opt-in PM6150L WLED5 backend. Patch 0254 adds an unverified Surya PS_HOLD/IMEM reset mapping and leaves PM6150 reboot-reason writes disabled. Patch 0255 adapts the PM6150 RTC wall-clock path but has not been built or hardware-verified. Patch 0256 adds an off-by-default cpufreq-hw probe and opt-in maximum OPP selector; it does not implement runtime frequency scaling and is unverified. Patch 0257 adds the Surya Adreno 618 read-only probe and patch 0259 adds opt-in GMU/SMMU/HFI/GX/PAS stages 2–6, capped at the common 180 MHz level. CP command submission and userspace rendering remain unimplemented; the path has not been built or hardware-verified. WLAN/BT, modem, audio, cameras, sensors, NFC, charger and the full Tianma panel/display path also remain incomplete. The inherited key, battery, USB, framebuffer and WLED paths have not been checked on a Surya iOS boot. Do not enable Poco F1 PMIC charger writes for Surya.

Fetch the latest build: `gh run download -R dipa-studio/ios-sweet -n xnu-kernel -D xnu/out`
