# This script builds, optimizes, and prepares Rust binaries (native and WebAssembly)
# for deployment and benchmarking. It handles:
#
# 1. Building the native Rust binary using cargo.
# 2. Building the WASM binary with the wasm32-wasi target.
# 3. Optimizing and stripping the WASM binary using wasm-opt and wasm-strip.
# 4. AOT-compiling the optimized WASM binary using:
#    - Wasmer (produces a .wasmu file, then optimizes it)
#    - Wasmtime (produces a .cwasm file, no further optimization needed)
#
# The resulting binaries are placed in the ./bin directory:
#   - <name>                       (native binary)
#   - <name>-o.wasm               (optimized WASM)
#   - <name>-wasmer-native-o.wasmu (AOT-compiled & optimized for Wasmer)
#   - <name>-wasmtime-native.cwasm (AOT-compiled for Wasmtime)
#
# Dependencies (Ubuntu):
#   sudo apt update
#   sudo apt install -y binaryen wabt wasmer wasmtime

#!/usr/bin/env bash
set -euo pipefail

NAME="mobilenet-oc-l"
BIN_DIR="./bin"
EXAMPLE_DIR="./target/release/examples"
WASM_DIR="./target/wasm32-wasi/release/examples"

NATIVE="$EXAMPLE_DIR/$NAME"
WASM="$WASM_DIR/$NAME.wasm"
WASM_OPT="$BIN_DIR/${NAME}-o.wasm"
WASMER_NATIVE="$BIN_DIR/${NAME}-wasmer-native.wasmu"
WASMTIME_NATIVE="$BIN_DIR/${NAME}-wasmtime-native.cwasm"

# Flags
SKIP_NATIVE=false
SKIP_WASM=false
SKIP_WASMER=false
SKIP_WASMTIME=false
CLEAN=false
OPT_ONLY=false

# Parse flags
for arg in "$@"; do
  case $arg in
    --skip-native) SKIP_NATIVE=true ;;
    --skip-wasm) SKIP_WASM=true ;;
    --skip-wasmer) SKIP_WASMER=true ;;
    --skip-wasmtime) SKIP_WASMTIME=true ;;
    --clean) CLEAN=true ;;
    --opt-only)
      OPT_ONLY=true
      SKIP_NATIVE=true
      SKIP_WASM=true
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--skip-native] [--skip-wasm] [--skip-wasmer] [--skip-wasmtime] [--opt-only] [--clean]"
      exit 1
      ;;
  esac
done

# Clean bin dir if needed
if [[ $CLEAN == true ]]; then
  echo ""
  echo "==> Cleaning bin directory"
  rm -rf "$BIN_DIR"
fi

mkdir -p "$BIN_DIR"

# Build native
if [[ $SKIP_NATIVE == false ]]; then
  echo ""
  echo "==> Step 1: Build native Rust binary"
  cargo build --release --example "$NAME"
  cp "$NATIVE" "$BIN_DIR/"
  echo "Native binary copied to $BIN_DIR/"
fi

# Build wasm
if [[ $SKIP_WASM == false ]]; then
  echo ""
  echo "==> Step 2: Build WASM binary (wasm32-wasi)"
  cargo build --release --example "$NAME" --target=wasm32-wasi
fi

# Optimize and strip wasm
if [[ $SKIP_WASM == false || $OPT_ONLY == true ]]; then
  echo ""
  echo "==> Step 3: Optimize and strip WASM binary"
  if [[ ! -f "$WASM" ]]; then
    echo "Error: Expected WASM file not found at $WASM"
    exit 1
  fi
  wasm-opt -Oz --enable-bulk-memory --enable-sign-ext -o "$WASM_OPT" "$WASM"
  wasm-strip "$WASM_OPT"
  echo "Optimized WASM: $WASM_OPT"
fi

# Compile and place Wasmer AOT binary
if [[ $SKIP_WASMER == false ]]; then
  echo ""
  echo "==> Step 4: AOT compile with Wasmer"
  wasmer compile "$WASM_OPT" -o "$WASMER_NATIVE"
  echo "Wasmer AOT output: $WASMER_NATIVE"
fi

# Compile and place Wasmtime AOT binary
if [[ $SKIP_WASMTIME == false ]]; then
  echo ""
  echo "==> Step 5: AOT compile with Wasmtime"
  wasmtime compile "$WASM_OPT" -o "$WASMTIME_NATIVE"
  echo "Wasmtime AOT output: $WASMTIME_NATIVE"
fi

# Final summary
echo ""
echo "==> Build complete:"
[[ -f "$BIN_DIR/$NAME" ]] && echo "  Native:               $BIN_DIR/$NAME"
[[ -f "$WASM_OPT" ]] && echo "  WASM (optimized):     $WASM_OPT"
[[ -f "$WASMER_NATIVE" ]] && echo "  Wasmer AOT:           $WASMER_NATIVE"
[[ -f "$WASMTIME_NATIVE" ]] && echo "  Wasmtime AOT:         $WASMTIME_NATIVE"
