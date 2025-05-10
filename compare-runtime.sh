#!/usr/bin/env bash
set -euo pipefail

REPEATS=5
INPUT="input.json"
NATIVE="./target/release/examples/local-test-oc"
WASM="./local-test-oc-o.wasm"

check_file() {
  if [[ ! -f "$1" ]]; then
    echo "Error: '$1' not found."
    exit 1
  fi
}

# Ensure input and binaries exist
check_file "$INPUT"
check_file "$NATIVE"
check_file "$WASM"

measure_time() {
  local cmd="$1"
  local label="$2"
  local total=0

  echo "==> Measuring $label..."

  for i in $(seq 1 "$REPEATS"); do
    local time_ns
    time_ns=$( { /usr/bin/time -f "%e" bash -c "$cmd" > /dev/null; } 2>&1 )
    echo "Run $i: ${time_ns}s"
    total=$(echo "$total + $time_ns" | bc)
  done

  local avg
  avg=$(echo "scale=3; $total / $REPEATS" | bc)
  echo "Average $label time: ${avg}s"
  echo ""
}

measure_time "$NATIVE < $INPUT" "native binary"
measure_time "wasmtime $WASM --dir=. < $INPUT" "WASM binary"
measure_time "wasmer run $WASM --dir=. < $INPUT" "WASM binary (wasmer)"
