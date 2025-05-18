#!/bin/bash

# Get label from argument, default to "run"
RUNTIME_LABEL=${1:-run}

ACTION="add"
INPUT_TEMPLATE="./inputs/add.json"
MAX_CONCURRENCY=15
DELAY_BETWEEN_LEVELS=5  # seconds

OUTPUT_FILE="concurrency_results_${RUNTIME_LABEL}.csv"
METRICS_FILE="host_metrics_${RUNTIME_LABEL}.csv"
# Create CSV headers
echo "Concurrency,Invocation,Time(ms),Success" > "$OUTPUT_FILE"
echo "Timestamp,Concurrency,CPU_Usage(%),Mem_Used(MB),Mem_Free(MB)" > "$METRICS_FILE"

function log_metrics {
  local concurrency=$1
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  # Sample CPU and Memory
  local cpu
  cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')  # idle % -> used
  local mem_info
  mem_info=$(free -m | awk '/Mem:/ {print $3","$4}')  # used, free in MB

  echo "$timestamp,$concurrency,$cpu,$mem_info" >> "$METRICS_FILE"
}

function invoke {
  local action=$1
  local input_file=$2
  local concurrency_level=$3
  local invocation_id=$4

  start=$(date +%s%3N)
  output=$(wsk action invoke "$action" --param-file "$input_file" --result --blocking 2>&1)
  sleep 1
  end=$(date +%s%3N)

  runtime=$((end - start))

  echo "$output" | jq '.result' &>/dev/null
  if [ $? -eq 0 ]; then
    echo "$concurrency_level,$invocation_id,$runtime,1" >> "$OUTPUT_FILE"
    echo "✅ Concurrency $concurrency_level - Invocation $invocation_id: $runtime ms"
  else
    echo "$concurrency_level,$invocation_id,$runtime,0" >> "$OUTPUT_FILE"
    echo "❌ Concurrency $concurrency_level - Invocation $invocation_id: $runtime ms"
  fi
}

# Ramp up concurrency
for ((c=1; c<=MAX_CONCURRENCY; c++)); do
  echo "[INFO] Starting batch with concurrency = $c"
  
  log_metrics "$c"  # record system state before
  
  for ((i=1; i<=c; i++)); do
    invoke "$ACTION" "$INPUT_TEMPLATE" "$c" "$i" &
  done
  wait

  log_metrics "$c"  # record system state after

  echo "[INFO] Finished batch with concurrency = $c"
  sleep "$DELAY_BETWEEN_LEVELS"
done

echo "[DONE] Results written to $OUTPUT_FILE"
echo "[METRICS] Host metrics written to $METRICS_FILE"
