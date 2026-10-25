# XNU for sweet

Built on GitHub's macOS arm64 runners by `.github/workflows/xnu.yml`, using
[blacktop/darwin-xnu-build](https://github.com/blacktop/darwin-xnu-build) (MIT) at a pinned commit.

- `MACOS_VERSION=13.5` -> xnu-8796 (same generation as iOS 16.6/16.7, the last iOS for iPhone 8).
- `patches/*.patch` are copied into the build script's patch dir and applied to the xnu tree with `git apply`.
- Output: `kernel.<config>.vmapple` (later: our own SWEET machine config) as a workflow artifact.

The current iOS 18 series lives in `patches-11215/`. The Surya bring-up command line enables shared SM7150 USB, PM6150L key and read-only PM6150 battery paths; patch 0251 skips the legacy I2C touch probe. The Surya Novatek SPI touch driver, panel/backlight path and Adreno 618 support remain unported. The inherited key and battery paths have not been checked on a Surya device. Do not enable Poco F1 PMIC charger writes for Surya.

Fetch the latest build: `gh run download -R dipa-studio/ios-sweet -n xnu-kernel -D xnu/out`
