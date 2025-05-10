#!/bin/bash

# This script optimizes and strips a WebAssembly (.wasm) binary for deployment.
# Tools used: wasm-opt (from binaryen), wasm-strip (from wabt)

# How to install dependencies on Ubuntu-based systems:
#   sudo apt update
#   sudo apt install -y binaryen wabt

#!/usr/bin/env bash
set -euo pipefail

VALID_OPTIONS=("mobilenet-oc" "local-test-oc")

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <wasm-name>"
  echo "Valid options: ${VALID_OPTIONS[*]}"
  exit 1
fi

NAME="$1"

# Check if name is valid
if [[ ! " ${VALID_OPTIONS[*]} " =~ " ${NAME} " ]]; then
  echo "Invalid option: '${NAME}'"
  echo "Valid options: ${VALID_OPTIONS[*]}"
  exit 1
fi

INPUT_WASM="./target/wasm32-wasi/release/examples/${NAME}.wasm"
OPTIMIZED_WASM="${NAME}-o.wasm"

# Ensure input exists
if [[ ! -f "$INPUT_WASM" ]]; then
  echo "Error: Input WASM file not found at $INPUT_WASM"
  exit 1
fi

echo "Running wasm-opt on $INPUT_WASM"
wasm-opt -Oz --enable-bulk-memory --enable-sign-ext -o "$OPTIMIZED_WASM" "$INPUT_WASM"

echo "Stripping $OPTIMIZED_WASM"
wasm-strip "$OPTIMIZED_WASM"

echo "Output written to $OPTIMIZED_WASM"
