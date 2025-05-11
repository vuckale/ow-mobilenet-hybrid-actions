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
wasm-opt -Oz --enable-bulk-memory --enable-sign-ext -o mobilenet-oc-o mobilenet-oc
wasm-strip mobilenet-oc-o
```

This produces the optimized and stripped WebAssembly binary `mobilenet-oc-o.wasm` in root directory which we will use in openwhisk later

## Local Test
To test wasm binary with web assembly runtime like `wasmtime` 

1. Build::
```bash
cargo build --release --example mobilenet-oc-l --target=wasm32-wasi
```
2. Optimize:
```bash
wasm-opt -Oz --enable-bulk-memory --enable-sign-ext -o mobilenet-oc-l-o mobilenet-oc-l
wasm-strip mobilenet-oc-l-o
```
3. Run:
```bash
wasmtime mobilenet-oc-l-o.wasm --dir=. < input.json
```

To test regular rust binary
1. Build:
```bash
cargo build --release --example mobilenet-oc-l
```
2. Run:
```
./target/release/examples/mobilenet-oc-l < input.json
```

## Benchmarks
There is script named `benchmark.sh` which you can run to benchmark local-test wasm and native binaries:
```bash
./benchmark.sh
```
```bash
Usage: ./benchmark.sh [--jit | --aot]
```

Results:
# WebAssembly vs Native Performance Benchmark Report

This report summarizes the results of benchmarking a Rust-based image classification tool compiled to both a native binary and a WebAssembly (WASM) binary using WASI. Three runtime environments were tested:

- Native Rust binary
- WASM binary executed via `wasmtime`
- WASM binary executed via `wasmer`

All tests were run on the same machine using consistent inputs and configuration.

---

## Cold Start Test

This test measures the time it takes to start and run each binary once. It reflects performance in short-lived, CLI-style, or serverless use cases.

| Runtime     | Avg Cold Start Time |
|-------------|---------------------|
| Native      | 0.438s              |
| Wasmtime    | 1.224s              |
| Wasmer      | 1.194s              |

**Observation:**  
The native binary starts and completes execution roughly **3× faster** than the WASM versions. `wasmer` performs slightly better than `wasmtime` in cold start, likely due to runtime startup optimizations.

---

## Warm Loop Test (100 Iterations)

This test runs each binary 100 times in a loop within a single shell process. It highlights throughput and runtime overhead, especially JIT warm-up behavior.

| Runtime     | Real Time | User Time | Sys Time |
|-------------|-----------|-----------|----------|
| Native      | 41.52s    | 35.48s    | 10.85s   |
| Wasmtime    | 118.53s   | 97.63s    | 20.17s   |
| Wasmer      | 117.02s   | 93.92s    | 23.77s   |

**Observation:**  
In warm-loop scenarios, the native binary maintains a consistent advantage. Both WASM runtimes are **approximately 2.8x slower** than native, but comparable to each other.

---

## Memory Usage

This test measures the peak memory usage (Maximum Resident Set Size) for each binary during a single run.

| Runtime     | Max RSS (kB) |
|-------------|--------------|
| Native      | 89,976       |
| Wasmtime    | 142,820      |
| Wasmer      | 222,512      |

**Observation:**
WASM runtimes use significantly more memory than the native binary. `wasmer` showed the highest peak memory usage, more than **2.5×** the native binary.  
Additionally, `wasmer` used approximately **80,000 kB more memory than `wasmtime`**, an increase of nearly **89%**, indicating a noticeably higher memory overhead even among WASM runtimes. This may reflect differences in runtime implementation, JIT strategies, or memory initialization.

---

## Binary Size

This test compares the on-disk sizes of the native and WASM binaries.

| Binary            | Size (bytes) |
|-------------------|--------------|
| Native            | 29,846,032   |
| WASM (optimized)  | 28,411,631   |

**Observation:**  
The optimized WASM binary is slightly smaller than the native ELF binary, although the difference is marginal given both include an embedded ML model.

---

## Throughput Test (100 Executions)

This test measures how many full runs per second each binary can handle based on wall clock timing.

| Runtime     | Total Time | Runs/sec |
|-------------|------------|----------|
| Native      | 42s        | 2.38     |
| Wasmtime    | 119s       | 0.84     |
| Wasmer      | 127s       | 0.78     |

**Observation:**  
The native binary achieved nearly **3× the throughput** of the WASM runtimes. This reinforces that while WASM is viable for isolated or portable deployments, it has a significant performance tradeoff for high-throughput workloads.

---

## Summary

- Native Rust is clearly the fastest in all categories.
- `wasmer` and `wasmtime` perform similarly overall.
- WASM comes with a tradeoff: portability and safety at the cost of speed and memory efficiency.
- If your use case is serverless, portable modules, or sandboxed execution, WASM remains viable — but for pure performance, native Rust is superior.

---

## Next Steps

- Consider AOT-compiling WASM with `wasmer compile` to close the performance gap.
- Profile real-world inputs with larger image sizes or model variants.
- Log startup latency and memory usage in real deployment conditions.

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
cargo build --release --example mobilenet-oc-l --target wasm32-wasi
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

## AOT Compilation: Closing the Gap with Native Performance

In the initial benchmarks, we compared a native Rust binary against WASM binaries executed with `wasmtime` and `wasmer`, both using Just-In-Time (JIT) compilation. This reflects how WebAssembly is commonly deployed today, particularly in serverless and plugin-based environments.

However, this comparison is not fully balanced. The native Rust binary is ahead-of-time (AOT) compiled and highly optimized, whereas JIT-based WASM includes runtime overhead due to compilation and setup. To better align the comparison and evaluate WASM at its full potential, we now include AOT-compiled WASM binaries using both Wasmer and Wasmtime.

This brings the comparison closer to apples-to-apples and helps reduce the performance gap introduced by JIT execution.

---

### AOT Compilation with Wasmer

Wasmer can precompile a `.wasm` file into a native-format `.wasm` that skips JIT entirely:

```bash
wasmer compile mobilenet-oc-l-o.wasm -o mobilenet-oc-l-wasmer-native.wasmu
```

Run the AOT binary with:

```bash
wasmer run mobilenet-oc-l-wasmer-native.wasm --dir=. < input.json
```

---

### AOT Compilation with Wasmtime

Wasmtime compiles to a `.cwasm` file, which stores a precompiled module for fast startup:

```bash
wasmtime compile mobilenet-oc-l-o.wasm -o mobilenet-oc-l-wasmtime-native.cwasm
```

Execution requires explicitly allowing precompiled modules:

```bash
wasmtime run --allow-precompiled mobilenet-oc-l-wasmtime-native.cwasm --dir=. < input.json
```

Wasmtime disables precompiled execution by default to avoid loading untrusted native code without user intent.

---

### Summary

Using AOT compilation allows us to evaluate WASM under conditions that are more directly comparable to native Rust binaries. By skipping JIT, we eliminate startup and runtime compilation overhead, providing a better measure of WASM's optimized performance.

| Runtime        | Compilation Type | Run Mode             | Notes                            |
|----------------|------------------|----------------------|----------------------------------|
| Native Rust    | AOT              | Native binary        | Fully optimized at build time    |
| WASM (Wasmer)  | AOT              | wasmer run           | Requires `wasmer compile`        |
| WASM (Wasmtime)| AOT              | wasmtime run         | Requires `--allow-precompiled`   |
| WASM (default) | JIT              | wasmer/wasmtime      | Includes runtime compilation     |

This extended benchmark helps determine not just how WASM performs in typical JIT configurations, but also how close it can get to native execution when compiled ahead of time.
