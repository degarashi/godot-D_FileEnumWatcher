#!/bin/bash

# Find Godot binary path
GODOT_BIN=$(which godot 2>/dev/null)
if [ -z "${GODOT_BIN}" ]; then
	if [ -x "/opt/godot" ]; then
		GODOT_BIN="/opt/godot"
	else
		echo "Error: Godot binary not found in PATH or at /opt/godot."
		exit 1
	fi
fi

echo "Using Godot binary: ${GODOT_BIN}"

# Run gdUnit4 tests
./addons/gdUnit4/runtest.sh --godot_binary "${GODOT_BIN}" -a test/ --ignoreHeadlessMode "$@"
