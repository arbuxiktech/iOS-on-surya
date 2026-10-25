#!/usr/bin/env bash
# Fetch the pinned SM7150 mainline DTS sources and build the two Surya panel DTBs.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SOURCE_DIR=${SURYA_LINUX_SRC:-"$ROOT/dtb/surya/linux-src"}
OUTPUT_DIR=${SURYA_DTB_OUT:-"$ROOT/dtb/surya"}
SOURCE_URL=https://github.com/sm7150-mainline/linux.git
SOURCE_REF=v7.2
SOURCE_COMMIT=fd78d17954a86ea6ceb0c535e618ea129e09f8dd
CPP=${CPP:-cpp}
DTC=${DTC:-dtc}

command -v "$CPP" >/dev/null || { echo "error: $CPP not found (install a C preprocessor)" >&2; exit 1; }
command -v "$DTC" >/dev/null || { echo "error: $DTC not found (install device-tree-compiler)" >&2; exit 1; }

mkdir -p "$(dirname "$SOURCE_DIR")" "$OUTPUT_DIR"
if [[ ! -d "$SOURCE_DIR/.git" ]]; then
	git clone --filter=blob:none --depth 1 --sparse --branch "$SOURCE_REF" "$SOURCE_URL" "$SOURCE_DIR"
fi
if ! git -C "$SOURCE_DIR" cat-file -e "$SOURCE_COMMIT^{commit}" 2>/dev/null; then
	git -C "$SOURCE_DIR" fetch --depth 1 origin "$SOURCE_COMMIT"
fi
git -C "$SOURCE_DIR" checkout --detach "$SOURCE_COMMIT"
git -C "$SOURCE_DIR" sparse-checkout init --cone
git -C "$SOURCE_DIR" sparse-checkout set \
	arch/arm64/boot/dts/qcom scripts/dtc include/dt-bindings include/uapi

QCOM="$SOURCE_DIR/arch/arm64/boot/dts/qcom"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for panel in huaxing tianma; do
	src="$QCOM/sm7150-xiaomi-surya-$panel.dts"
	"$CPP" -nostdinc \
		-I "$SOURCE_DIR/include" \
		-I "$SOURCE_DIR/scripts/dtc/include-prefixes" \
		-I "$SOURCE_DIR/arch/arm64/boot/dts" \
		-undef -D__DTS__ -x assembler-with-cpp "$src" > "$tmp/surya-$panel.dts"
	"$DTC" -I dts -O dtb -i "$QCOM" \
		-o "$OUTPUT_DIR/surya-$panel.dtb" "$tmp/surya-$panel.dts"
	"$DTC" -I dtb -O dts "$OUTPUT_DIR/surya-$panel.dtb" >/dev/null
done

printf 'Built Surya Huaxing and Tianma reference DTBs from %s (%s).\n' "$SOURCE_REF" "$SOURCE_COMMIT"
printf 'These mainline Linux DTBs are not stock Xiaomi DTBs; match the phone panel and stock FDT before boot use.\n'
