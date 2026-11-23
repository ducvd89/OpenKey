#!/bin/sh
# Builds the engine with the test runner and runs every check. Extra arguments go to the runner,
# for example: ./run.sh --seed 42      replay one fuzz seed
#              ./run.sh --type restore "posts " "theme "      show what a key sequence types
set -e
cd "$(dirname "$0")"
out="${TMPDIR:-/tmp}/openkey-engine-test"
c++ -std=c++14 -g -O1 -w -fsanitize=address,undefined -fno-sanitize-recover=undefined \
    -I.. -I../platforms \
    engine_test.cpp ../Engine.cpp ../Vietnamese.cpp ../Macro.cpp ../SmartSwitchKey.cpp ../ConvertTool.cpp \
    -o "$out"
"$out" --dir . "$@"
