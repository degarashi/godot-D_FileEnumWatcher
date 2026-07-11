#!/bin/bash
set -euo pipefail

GODOT_BIN=${GODOT_BIN:-${GODOT_PATH:-$(which godot)}}

if [ ! -f "$GODOT_BIN" ]; then
	echo "Error: Godot binary not found at $GODOT_BIN" >&2
	echo "Godot binary not found. Checked: GODOT_BIN='$GODOT_BIN'" >&2
	exit 1
fi

if [ ! -x "$GODOT_BIN" ]; then
	echo "Error: Godot binary is not executable: $GODOT_BIN" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GDUNIT_RUNNER="$SCRIPT_DIR/addons/gdUnit4/runtest.sh"
if [ ! -f "$GDUNIT_RUNNER" ]; then
	echo "Error: gdUnit4 runner not found at $GDUNIT_RUNNER" >&2
	exit 1
fi

export GODOT_BIN

TEST_DIR="tests"

while getopts "a:" opt; do
	case $opt in
		a) TEST_DIR="$OPTARG" ;;
		*) echo "Usage: $0 [-a test_dir]" >&2; exit 1 ;;
	esac
done
shift $((OPTIND - 1))

exec "$GDUNIT_RUNNER" -a "$TEST_DIR" "$@"
