# mobilenet-infer-benchmark

Run image classification with MobileNet in both WebAssembly and native Rust, using `tract` for inference. Designed to support performance comparisons between runtimes.

## Features

- MobileNet V2 inference using a frozen `.pb` model
- Inference powered by `tract-tensorflow`
- WebAssembly support with OpenWhisk-compatible interface

Tested with with Rust `1.83.0`. Make sure you are using it with:
```bash
rustup default 1.83.0
```

And then build:
```bash
cargo build --release --example mobilenet-oc --target=wasm32-wasi --features=wasm
```

Then optimize it:

```bash
./optimize-target.sh mobilenet-oc
```

This produces the optimized and stripped WebAssembly binary `mobilenet-oc-o.wasm` in root directory which we will use in openwhisk later

## Local Test
To test wasm binary with web assembly runtime like `wasmtime` 

1. Build::
```bash
cargo build --release --example local-test-oc --target=wasm32-wasi
```
2. Optimize:
```bash
./optimize-target.sh local-test-oc
```
3. Run:
```bash
wasmtime local-test-oc-o.wasm --dir=. < input.json
```

To test regular rust binary
1. Build:
```bash
cargo build --release --example local-test-oc
```
2. Run:
```
./target/release/examples/local-test-oc < input.json
```

## Benchmarks
There is script named `compare-runtime.sh` which you can run to benchmark local-test wasm and native binaries:
```bash
./compare-runtime.sh
```

Results:
```
==> Measuring native binary...
Run 1: 0.42s
Run 2: 0.43s
Run 3: 0.43s
Run 4: 0.43s
Run 5: 0.41s
Average native binary time: .424s

==> Measuring WASM binary...
Run 1: 1.30s
Run 2: 1.22s
Run 3: 1.24s
Run 4: 1.20s
Run 5: 1.23s
Average WASM binary time: 1.238s

==> Measuring WASM binary (wasmer)...
Run 1: 1.23s
Run 2: 1.30s
Run 3: 1.30s
Run 4: 1.28s
Run 5: 1.30s
Average WASM binary (wasmer) time: 1.282s
```

# WebAssembly Runtime Comparison and Performance Notes

## Why the WASM Binary is Slower

When comparing a native Rust binary to its WebAssembly (WASM) equivalent running under a runtime like `wasmtime` or `wasmer`, it's expected that the WASM version will be noticeably slower. This performance difference comes from several architectural and runtime factors.

WASM runtimes like `wasmtime` must parse, validate, and JIT-compile the WebAssembly binary at runtime, which adds overhead during execution. In contrast, native Rust binaries are compiled directly to machine code ahead of time with full optimizations enabled by `cargo build --release`, resulting in faster and more efficient execution.

Another factor is WASI, the WebAssembly System Interface. WASI provides a standardized set of system APIs that allow WASM programs to perform operations like reading files, accessing environment variables, or working with standard input and output. While this abstraction makes WASM portable and secure, it introduces additional layers between the program and the actual system calls, making I/O operations slower than native equivalents.

JIT warm-up time also plays a role. WASM runtimes typically compile code just-in-time as it's needed. This means the first few invocations of a function will include the cost of compiling that function, which increases the runtime of short-lived processes or cold starts.

Finally, WASM's memory model contributes to slower performance. It uses a linear memory with strict bounds checking on every access to ensure safety. Native Rust code, on the other hand, can perform unchecked or highly optimized memory operations when compiled in release mode, which gives it a significant speed advantage in memory-intensive workloads.

## Is This a Problem?

It depends on the goal:

- For deployment in a WebAssembly runtime (e.g., serverless platforms, browsers, or sandboxed plugin systems), this performance overhead is acceptable and expected.
- For performance-critical workloads, native Rust is significantly faster. WASM is best suited for portability, isolation, and safety.


## What is WASI?

WASI (WebAssembly System Interface) is a standard that provides system-like capabilities to WebAssembly programs. It allows operations like reading from `stdin`, writing to `stdout`, accessing the file system, etc., in a sandboxed and secure way.

In this project, I compiled my Rust code to the `wasm32-wasi` target, which:
- Enables the Rust standard library (via WASI shims).
- Allows my code to use `std::io::stdin()`, `std::fs::read_to_string`, and other familiar APIs.
- Makes the compiled `.wasm` file runnable via WASI-compliant runtimes like `wasmtime` or `wasmer`.

Example compilation:
```bash
cargo build --release --example local-test-oc --target wasm32-wasi
```

## How to Install WASM Runtimes

### Wasmtime (Linux)
```bash
curl https://wasmtime.dev/install.sh -sSf | bash
```

### Wasmer (Linux)
```bash
curl https://get.wasmer.io -sSfL | bash
```

## Why We Aren’t Using WasmEdge or WAVM

### WasmEdge

- WasmEdge currently has **inconsistent support for stdin**, especially when redirecting input via `< input.json`.
- Our program reads input from `stdin` using `std::io::stdin().read_to_string()`, which doesn't work reliably with WasmEdge.
- We chose not to modify our code just to support this one runtime.

### WAVM

- WAVM is a high-performance WebAssembly runtime but is complex to install and lacks first-class tooling support like `wasmtime` or `wasmer`.
- It does not provide practical advantages for our current use case over easier alternatives.
