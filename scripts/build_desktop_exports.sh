#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
project_dir="$repo_dir/godot"
dist_dir="$repo_dir/dist"
project_version=$(sed -n 's/^config\/version="\([^"]*\)"$/\1/p' "$project_dir/project.godot")
version=${VERSION:-$project_version}

case "$version" in
	*[!A-Za-z0-9._-]*|'')
		echo "VERSION may contain only letters, numbers, dots, underscores, and hyphens." >&2
		exit 2
		;;
esac

if [ -n "${GODOT_BIN:-}" ]; then
	if [ ! -x "$GODOT_BIN" ]; then
		echo "GODOT_BIN is not executable: $GODOT_BIN" >&2
		exit 2
	fi
	Godot="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
	Godot=$(command -v godot)
elif command -v godot4 >/dev/null 2>&1; then
	Godot=$(command -v godot4)
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
	Godot="/Applications/Godot.app/Contents/MacOS/Godot"
else
	echo "Godot 4.7.2 was not found. Set GODOT_BIN to the editor executable." >&2
	exit 2
fi

godot_version=$("$Godot" --version)
case "$godot_version" in
	4.7.2.*) ;;
	*)
		echo "Godot 4.7.2 is required; found $godot_version" >&2
		exit 2
		;;
esac

if [ "$#" -eq 0 ]; then
	set -- windows macos linux
fi

for target in "$@"; do
	case "$target" in
		windows|macos|linux) ;;
		*)
			echo "Unknown target '$target'. Use windows, macos, or linux." >&2
			exit 2
			;;
	esac
done

mkdir -p "$dist_dir"
staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/capitalism-export.XXXXXX")
trap 'rm -rf -- "$staging_dir"' EXIT HUP INT TERM

export_project() {
	preset=$1
	output=$2
	mkdir -p "$(dirname -- "$output")"
	echo "Exporting $preset..."
	if ! "$Godot" --headless --path "$project_dir" --export-release "$preset" "$output"; then
		echo "Export failed. In Godot, use Editor > Manage Export Templates and install the 4.7.2 templates." >&2
		exit 1
	fi
	if [ ! -f "$output" ]; then
		echo "Godot did not create the expected output: $output" >&2
		echo "Install the Godot 4.7.2 export templates and try again." >&2
		exit 1
	fi
}

for target in "$@"; do
	case "$target" in
		windows)
			windows_dir="$staging_dir/windows"
			windows_binary="$windows_dir/CapitalismWithCards.exe"
			windows_archive="$dist_dir/capitalism-with-cards-$version-windows-x86_64.zip"
			export_project "Windows Desktop" "$windows_binary"
			rm -f -- "$windows_archive"
			(cd "$windows_dir" && zip -q -9 "$windows_archive" "CapitalismWithCards.exe")
			;;
		macos)
			macos_archive="$dist_dir/capitalism-with-cards-$version-macos-universal.zip"
			rm -f -- "$macos_archive"
			export_project "macOS" "$macos_archive"
			;;
		linux)
			linux_dir="$staging_dir/linux"
			linux_binary="$linux_dir/CapitalismWithCards.x86_64"
			linux_archive="$dist_dir/capitalism-with-cards-$version-linux-x86_64.tar.gz"
			export_project "Linux" "$linux_binary"
			chmod +x "$linux_binary"
			rm -f -- "$linux_archive"
			LC_ALL=C tar -C "$linux_dir" -czf "$linux_archive" "CapitalismWithCards.x86_64"
			;;
	esac
done

(
	export LC_ALL=C
	cd "$dist_dir"
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum capitalism-with-cards-"$version"-* > SHA256SUMS
	else
		shasum -a 256 capitalism-with-cards-"$version"-* > SHA256SUMS
	fi
)

echo "Desktop packages are ready in $dist_dir:"
find "$dist_dir" -maxdepth 1 -type f -print | sort
