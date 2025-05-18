#!/bin/bash

# Action names
ACTION="add"
PARALLEL_ACTIONS=("mobilenet_native_rust1" "mobilenet_native_rust2" "mobilenet_native_rust3")

INPUT_DIR="./inputs"
ITERATIONS=11
ITERATIONS_COLD=3
COLD_START_WAIT=605  # 10 minutes

function log {
  echo "[$(date '+%H:%M:%S')] $1"
}

function invoke_action {
  local action_name=$1
  local input_file=$2
  local run_label=$3

  start=$(date +%s%3N)
  output=$(wsk action invoke "$action_name" --param-file "$input_file" --result --blocking 2>&1)
  end=$(date +%s%3N)

  runtime=$((end - start))
  echo "$run_label,$action_name,$input_file,$runtime" >> results.csv

  echo -n "$run_label ($input_file with $action_name): $runtime ms"

  echo "$output" | jq '.result' &>/dev/null
  if [ $? -ne 0 ]; then
    echo " ❌ ERROR"
  else
    echo " ✅"
  fi
}

echo "Run,Action,Input,Time(ms)" > results.csv

log "=== Warm Start Tests ==="
for file in "$INPUT_DIR"/*.json; do
  for ((i=1; i<=ITERATIONS; i++)); do
    invoke_action "$ACTION" "$file" "warm-$i"
  done
done

log "=== Cold Start Tests (wait $COLD_START_WAIT seconds between runs) ==="
for file in "$INPUT_DIR"/*.json; do
  for ((i=1; i<=ITERATIONS_COLD; i++)); do
    log "Sleeping to simulate cold start..."
    sleep $COLD_START_WAIT
    invoke_action "$ACTION" "$file" "cold-$i"
  done
done

# log "=== Concurrency Test ==="
# for file in "$INPUT_DIR"/*.json; do
#   for i in {0..1}; do
#     (
#       invoke_action "${PARALLEL_ACTIONS[$i]}" "$file" "parallel-$(($i+1))" &
#     )
#   done
#   wait
# done

log "=== Done. Results saved to results.csv ==="
