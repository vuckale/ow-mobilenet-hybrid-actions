#!/usr/bin/env bash
set -euo pipefail

# Parse command-line flags
MODE=""
for arg in "$@"; do
  case $arg in
    --jit)
      MODE="jit"
      ;;
    --aot)
      MODE="aot"
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--jit | --aot ]"
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 [--jit | --aot]"
  exit 1
fi

REPEATS=5
WARM_RUNS=100
INPUT="./inputs/cat1.json"
BIN="../bin"
NATIVE="$BIN/mobilenet-oc-l"
WASM="$BIN/mobilenet-oc-l-o.wasm"
check_file() {
  if [[ ! -f "$1" ]]; then
    echo "Error: '$1' not found."
    exit 1
  fi
}
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

run_timed_loop() {
    local label="$1"
    local cmd="$2"
    { time for i in $(seq 1 "$WARM_RUNS"); do eval "$cmd" > /dev/null; done; } 2>&1 \
        | sed "1s/^/-- $label /; 2,\$s/^/   /"
}

print_mem_usage() {
    local label="$1"
    local cmd="$2"
    echo "-- $label:"
    /usr/bin/time -v bash -c "$cmd" 2>&1 | grep -i "maximum resident set size"
}

print_size() {
    local label="$1"
    local file="$2"
    if [[ -f "$file" ]]; then
        size=$(stat -c %s "$file")
        echo "$label: $file = $size bytes"
    else
        echo "$label: $file not found"
    fi
}

run_throughput() {
    local label="$1"
    local cmd="$2"
    echo "-- $label:"
    local start end elapsed
    start=$(date +%s)
    for i in $(seq 1 "$WARM_RUNS"); do
        eval "$cmd" > /dev/null
    done
    end=$(date +%s)
    elapsed=$((end - start))
    if [[ $elapsed -eq 0 ]]; then
        echo "  Skipped: Elapsed time too short to measure throughput."
    else
        local rate
        rate=$(echo "scale=2; $WARM_RUNS / $elapsed" | bc)
        echo "  $WARM_RUNS runs in $elapsed seconds => $rate runs/sec"
    fi
}

###
if [[ $MODE == "jit" ]]; then
  echo "==> Cold Start Test (single run)"
  echo "This test measures the time it takes to start and run each binary once. It reflects performance in short-lived, CLI-style or serverless use cases."
  measure_time "$NATIVE < $INPUT" "Native cold start"
  measure_time "wasmtime $WASM --dir=. < $INPUT" "WASM (wasmtime) cold start"
  measure_time "wasmer run $WASM --dir=. < $INPUT" "WASM (wasmer) cold start"

  echo ""
  echo "==> Warm Loop Test ($WARM_RUNS runs in a single shell)"
  echo "This test runs each binary $WARM_RUNS times in a loop within a single shell process. It highlights throughput and JIT warm-up behavior."
  run_timed_loop "Native" "$NATIVE < $INPUT"
  run_timed_loop "WASM (wasmtime)" "wasmtime $WASM --dir=. < $INPUT"
  run_timed_loop "WASM (wasmer)" "wasmer run $WASM --dir=. < $INPUT"

  echo ""
  echo "==> Memory Usage (Maximum Resident Set Size)"
  echo "This test measures the peak memory usage (Maximum Resident Set Size) for each binary during a single run."
  print_mem_usage "Native" "$NATIVE < $INPUT"
  print_mem_usage "WASM (wasmtime)" "wasmtime $WASM --dir=. < $INPUT"
  print_mem_usage "WASM (wasmer)" "wasmer run $WASM --dir=. < $INPUT"

  echo ""
  echo "==> Binary Sizes (in bytes)"
  echo "This test compares the actual on-disk size of the native binary and the WASM binary."
  print_size "Native" "$NATIVE"
  print_size "WASM (wasmtime/wasmer)" "$WASM"

  echo ""
  echo "==> Throughput Test (wall time for $WARM_RUNS runs)"
  echo "This test measures how many runs per second each binary can handle, based on the wall clock time for $WARM_RUNS full executions."
  run_throughput "Native" "$NATIVE < $INPUT"
  run_throughput "WASM (wasmtime)" "wasmtime $WASM --dir=. < $INPUT"
  run_throughput "WASM (wasmer)" "wasmer run $WASM --dir=. < $INPUT"

elif [[ $MODE == "aot" ]]; then
  WASM_WASMTIME_AOT="$BIN/mobilenet-oc-l-wasmtime-native.cwasm"
  WASM_WASMER_AOT="$BIN/mobilenet-oc-l-wasmer-native.wasmu"

  check_file "$WASM_WASMTIME_AOT"
  check_file "$WASM_WASMER_AOT"

  echo ""
  echo "==> Cold Start Test (AOT)"
  echo "This test repeats the cold start benchmark, but using ahead-of-time compiled WASM binaries."
  measure_time "$NATIVE < $INPUT" "Native cold start"
  measure_time "wasmtime run --allow-precompiled $WASM_WASMTIME_AOT --dir=. < $INPUT" "WASM (wasmtime AOT) cold start"
  measure_time "wasmer run $WASM_WASMER_AOT --dir=. < $INPUT" "WASM (wasmer AOT) cold start"

  echo ""
  echo "==> Warm Loop Test (AOT - $WARM_RUNS runs in a single shell)"
  echo "This test runs each AOT binary $WARM_RUNS times in a loop to measure throughput without JIT overhead."
  run_timed_loop "Native" "$NATIVE < $INPUT"
  run_timed_loop "WASM (wasmtime AOT)" "wasmtime run --allow-precompiled $WASM_WASMTIME_AOT --dir=. < $INPUT"
  run_timed_loop "WASM (wasmer AOT)" "wasmer run $WASM_WASMER_AOT --dir=. < $INPUT"

  echo ""
  echo "==> Memory Usage (AOT - Maximum Resident Set Size)"
  echo "This test measures peak memory usage for AOT-compiled WASM binaries."
  print_mem_usage "Native" "$NATIVE < $INPUT"
  print_mem_usage "WASM (wasmtime AOT)" "wasmtime run --allow-precompiled $WASM_WASMTIME_AOT --dir=. < $INPUT"
  print_mem_usage "WASM (wasmer AOT)" "wasmer run $WASM_WASMER_AOT --dir=. < $INPUT"

  echo ""
  echo "==> Binary Sizes (AOT - in bytes)"
  echo "This test compares the size of AOT-compiled WASM binaries."
  print_size "Native" "$NATIVE"
  print_size "WASM (wasmtime AOT)" "$WASM_WASMTIME_AOT"
  print_size "WASM (wasmer AOT)" "$WASM_WASMER_AOT"

  echo ""
  echo "==> Throughput Test (AOT - wall time for $WARM_RUNS runs)"
  echo "This test measures throughput using AOT binaries without runtime compilation delay."
  run_throughput "Native" "$NATIVE < $INPUT"
  run_throughput "WASM (wasmtime AOT)" "wasmtime run --allow-precompiled $WASM_WASMTIME_AOT --dir=. < $INPUT"
  run_throughput "WASM (wasmer AOT)" "wasmer run $WASM_WASMER_AOT --dir=. < $INPUT"
fi
