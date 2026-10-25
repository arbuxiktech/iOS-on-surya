#!/bin/sh
# Build and ad-hoc sign the on-device tools for iOS 16 -> research/sweetnet/
# (sweetnetcfg, cscheck, hcitest, bluetool-stub, sweetreboot, sweetdur = UFS durability test, kernel 0221; set TOOLS="hcitest" to build a subset; sweetreboot = reboot-to-fastboot, kernel 0137)
# iOS 18: also research/sweetnet/ios18/ (arm64e + pacstrip by default; native arm64 selectable for Surya)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=${SWEETNET_OUT:-$here/../../research/sweetnet}
mkdir -p "$out"
for t in ${TOOLS:-sweetnetcfg cscheck hcitest bluetool-stub sweetreboot sweetdur sweettouch}; do
	ents=$here/entitlements.plist
	case $t in
	cscheck) frameworks="-framework CoreFoundation -framework Security" ;;
	hcitest|sweetreboot|sweetdur) frameworks="" ;;
	sweettouch) frameworks="-framework CoreFoundation -framework IOKit"; ents=$here/touch.entitlements ;;
	bluetool-stub) frameworks=""; ents=$here/bluetool.entitlements ;;
	*) frameworks="-framework CoreFoundation" ;;
	esac
	xcrun -sdk iphoneos clang -arch arm64 -mios-version-min=16.0 -O2 -Wall \
		$frameworks "$here/$t.c" -o "$out/$t"
	codesign -s - -f --entitlements "$ents" "$out/$t"
	ls -l "$out/$t"
done
# LaunchServices register tool for sideloaded apps (tools/sweet-install-ipa.sh)
xcrun -sdk iphoneos clang -arch arm64 -mios-version-min=16.0 -O2 -fobjc-arc \
	-framework Foundation "$here/sweetuicache.m" -o "$out/sweetuicache"
codesign -s - -f --entitlements "$here/uicache.entitlements" "$out/sweetuicache"

# iOS 18 (Renegade): arm64e builds are PAC-stripped; Surya can use native arm64 builds.
# Output: $SWEETNET_OUT/ios18/ (set IOS18=0 to skip, IOS18_ARCH=arm64 for Surya).
if [ "${IOS18:-1}" = 1 ]; then
	out18=$out/ios18
	pacstrip=$here/../renegade/pacstrip.py
	IOS18_ARCH=${IOS18_ARCH:-arm64e}
	IOS18_MIN_VERSION=${IOS18_MIN_VERSION:-18.0}
	case $IOS18_ARCH in arm64|arm64e) ;; *) echo "build.sh: IOS18_ARCH must be arm64 or arm64e" >&2; exit 2 ;; esac
	mkdir -p "$out18"
	sign18() {
		f=$1; ent=${2:-}
		if [ -n "$ent" ]; then codesign -s - -f --entitlements "$ent" "$f"; else codesign -s - -f "$f"; fi
		if [ "$IOS18_ARCH" = arm64e ]; then python3 -I "$pacstrip" --sign "$f"; fi
	}
	# sweetprefs: set/read a user default through cfprefsd (installed in /usr/local/bin by root_tweaks18.base())
	xcrun -sdk iphoneos clang -arch "$IOS18_ARCH" -mios-version-min="$IOS18_MIN_VERSION" -O2 -Wall -framework CoreFoundation \
		"$here/sweetprefs.c" -o "$out18/sweetprefs"
	sign18 "$out18/sweetprefs" "$here/entitlements.plist"
	# sweetdur: UFS/HFS durability test (kernel patch 0221)
	xcrun -sdk iphoneos clang -arch "$IOS18_ARCH" -mios-version-min="$IOS18_MIN_VERSION" -O2 -Wall "$here/sweetdur.c" -o "$out18/sweetdur"
	sign18 "$out18/sweetdur" "$here/entitlements.plist"
	# sweetuicache: LaunchServices registration, run by the first-boot job (root_tweaks18.firstboot)
	xcrun -sdk iphoneos clang -arch "$IOS18_ARCH" -mios-version-min="$IOS18_MIN_VERSION" -O2 -fobjc-arc \
		-framework Foundation "$here/sweetuicache.m" -o "$out18/sweetuicache"
	sign18 "$out18/sweetuicache" "$here/uicache.entitlements"
	# sweetfp.dylib: NSURLFileProtectionKey shim, linked into PosterBoard (root_tweaks18.posterboard)
	xcrun -sdk iphoneos clang -arch "$IOS18_ARCH" -mios-version-min="$IOS18_MIN_VERSION" -O2 -fobjc-arc -dynamiclib \
		-install_name /usr/local/lib/sweetfp.dylib -framework Foundation \
		"$here/sweetfp.m" -o "$out18/sweetfp.dylib"
	sign18 "$out18/sweetfp.dylib"
	ls -l "$out18"
fi

# First-boot wallpaper/icon style and the mobile-domain runner (root_tweaks18.firstboot, same IOS18_ARCH profile)
if [ "${IOS18:-1}" = 1 ]; then
	out18=$out/ios18
	pacstrip=$here/../renegade/pacstrip.py
	b18() { # name source entitlements [extra clang args]
		n=$1; src=$2; ents=$3; shift 3
		xcrun -sdk iphoneos clang -arch "$IOS18_ARCH" -mios-version-min="$IOS18_MIN_VERSION" -O2 -fobjc-arc -framework Foundation "$@" \
			"$here/$src" -o "$out18/$n"
		sign18 "$out18/$n" "$here/$ents"
	}
	# sweetmetrics: Bergamota live metrics (docs/BERGAMOTA_METRICS.md), plain C, root_tweaks18.sweetmetrics
	xcrun -sdk iphoneos clang -arch "$IOS18_ARCH" -mios-version-min="$IOS18_MIN_VERSION" -O2 -Wall -framework CoreFoundation -framework IOKit \
		"$here/sweetmetrics.c" -o "$out18/sweetmetrics"
	sign18 "$out18/sweetmetrics" "$here/entitlements.plist"
	b18 sweetposterset sweetposterset.m posterset.entitlements
	b18 sweeticonstyle sweeticonstyle.m iconstyle.entitlements -framework UIKit
	b18 sweetopen sweetopen.m uicache.entitlements
	# remote testing over SSH: screenshot of the panel (PNG) and synthetic touch/buttons
	b18 sweetshot sweetshot.m touch.entitlements -framework CoreGraphics -framework ImageIO -framework IOSurface \
		-framework QuartzCore
	# a CPU profile of one process over SSH (running threads only, frame-pointer stacks, aggregated on the phone)
	xcrun -sdk iphoneos clang -arch "$IOS18_ARCH" -mios-version-min="$IOS18_MIN_VERSION" -O2 -Wall "$here/sweetsample.c" -o "$out18/sweetsample"
	sign18 "$out18/sweetsample" "$here/sample.entitlements"
	# the unified log over SSH (no `log` tool on iOS)
	b18 sweetlog sweetlog.m log.entitlements -framework OSLog
	xcrun -sdk iphoneos clang -arch "$IOS18_ARCH" -mios-version-min="$IOS18_MIN_VERSION" -O2 -Wall -framework CoreFoundation -framework IOKit \
		"$here/sweettouch.c" -o "$out18/sweettouch"
	sign18 "$out18/sweettouch" "$here/touch.entitlements"
	# SweetRun.app: runs /private/var/tmp/sweetrun.sh as mobile in the user's launchd domain (an app started by FrontBoard)
	app=$out18/SweetRun.app
	rm -rf "$app"; mkdir -p "$app"
	cp "$here/sweetrun-app/Info.plist" "$app/Info.plist"
	xcrun -sdk iphoneos clang -arch "$IOS18_ARCH" -mios-version-min="$IOS18_MIN_VERSION" -O2 -fobjc-arc -framework UIKit -framework Foundation \
		"$here/sweetrun-app/sweetrun.m" -o "$app/SweetRun"
	codesign -s - -f --entitlements "$here/sweetrun-app/run.entitlements" "$app"
	if [ "$IOS18_ARCH" = arm64e ]; then python3 -I "$pacstrip" --sign "$app/SweetRun"; fi
	codesign -s - -f --entitlements "$here/sweetrun-app/run.entitlements" "$app"      # seal the bundle again
	ls -l "$out18"
fi
