#!/bin/bash

# This script optimizes and strips a WebAssembly (.wasm) binary for deployment.
# Tools used: wasm-opt (from binaryen), wasm-strip (from wabt)

# How to install dependencies on Ubuntu-based systems:
#   sudo apt update
#   sudo apt install -y binaryen wabt

# Input and output files
INPUT_WASM="./target/wasm32-wasi/release/examples/mobilenet-oc.wasm"
OPTIMIZED_WASM="mobilenet-oc-o.wasm"

# Step 1: Optimize the WASM file
echo "Running wasm-opt..."
wasm-opt -Oz --enable-bulk-memory --enable-sign-ext \
  -o "$OPTIMIZED_WASM" \
  "$INPUT_WASM"

# Step 2: Only strip if wasm-opt succeeded
if [ $? -eq 0 ]; then
  echo "Optimization succeeded, running wasm-strip..."
  wasm-strip "$OPTIMIZED_WASM"
  echo "Stripping completed."
else
  echo "wasm-opt failed. Skipping wasm-strip."
  exit 1
fi
