# WebAssembly vs Native Performance on bare metal - Benchmark Report

This report summarizes the results of benchmarking a Rust-based image classification tool compiled to both a native binary and a WebAssembly (WASM) binary using WASI. Three runtime environments were tested:

- Native Rust binary
- WASM binary executed via `wasmtime`
- WASM binary executed via `wasmer`

All tests were run on the same machine using consistent inputs and configuration.

## JIT Performance Tests and Comparison

This section evaluates performance of WebAssembly (WASM) binaries executed using **Just-In-Time (JIT)** compilation via **wasmtime** and **wasmer**, compared against a native Rust binary. These tests highlight runtime behavior under dynamic compilation.


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

## AOT Performance Tests and Comparison

This section extends the benchmark analysis by evaluating **Ahead-of-Time (AOT)** compiled WebAssembly binaries, executed via both **wasmtime** and **wasmer**. The same image classification tool was compiled with AOT settings and tested under the same conditions as the earlier JIT benchmarks.

### Cold Start Test (AOT)
This test measures time to start and complete execution once. It reflects performance in short-lived executions, especially relevant for serverless or CLI tools.

| Runtime         | Avg Cold Start Time |
|------------------|---------------------|
| Native           | 0.520s              |
| Wasmtime (AOT)   | 1.152s              |
| Wasmer (AOT)     | 1.364s              |

**Observation:**  
Cold start times for AOT binaries are still over 2× slower than native. Compared to JIT:
- Wasmtime AOT is **slightly faster** than JIT (1.152s vs 1.224s).
- Wasmer AOT is **slightly slower** than JIT (1.364s vs 1.194s).

This suggests AOT has **minimal impact** on cold start performance, with runtime initialization and IO dominating startup time.

---

### Warm Loop Test (AOT – 100 Iterations)
This test runs each binary 100 times within a single shell process to highlight sustained throughput and CPU efficiency.

| Runtime         | Real Time | User Time | Sys Time |
|------------------|-----------|------------|----------|
| Native           | 42.12s    | 32.95s     | 9.11s    |
| Wasmtime (AOT)   | 104.03s   | 92.60s     | 8.46s    |
| Wasmer (AOT)     | 102.83s   | 87.28s     | 16.52s   |

**Observation:**  
Both WASM runtimes show a ~12% performance improvement compared to their JIT versions:
- Wasmtime: 118.53s (JIT) → 104.03s (AOT)
- Wasmer: 117.02s (JIT) → 102.83s (AOT)

However, they still remain ~2.4× slower than native execution.

---

### Memory Usage (Max RSS – AOT)
Peak memory usage was captured during a single execution.

| Runtime         | Max RSS (kB) |
|------------------|--------------|
| Native           | 92,268       |
| Wasmtime (AOT)   | 110,464      |
| Wasmer (AOT)     | 238,720      |

**Observation:**  
- Wasmtime AOT uses **less memory** than its JIT version (↓ ~23%).
- Wasmer AOT uses **more memory** than JIT (+7%), reaching over 2.5× native memory use.

AOT reduces runtime memory in Wasmtime, but not in Wasmer, likely due to differing JIT/runtime architectures and preloading strategies.

---

### Binary Size (On-Disk)

| Binary             | Size (bytes) |
|--------------------|--------------|
| Native             | 29,846,032   |
| Wasmtime AOT       | 40,515,912   |
| Wasmer AOT         | 44,030,232   |

**Observation:**  
AOT binaries are **substantially larger** than native or JIT WASM:
- Wasmtime AOT is ~36% larger than native
- Wasmer AOT is ~47% larger

This contrasts with JIT builds, where WASM binaries were slightly **smaller** than the native binary.

---

### Throughput Test (100 Executions – AOT)

| Runtime         | Total Time | Runs/sec |
|------------------|-------------|-----------|
| Native           | 41s         | 2.43      |
| Wasmtime (AOT)   | 87s         | 1.14      |
| Wasmer (AOT)     | 79s         | 1.26      |

**Observation:**  
AOT improves throughput significantly over JIT:
- Wasmtime: 0.84 (JIT) → 1.14 (AOT) runs/sec
- Wasmer: 0.78 (JIT) → 1.26 (AOT) runs/sec

For the first time, **Wasmer outperforms Wasmtime** in throughput, though both still trail behind native by almost 2×.

---

### Summary of AOT vs JIT

| Metric               | Wasmtime JIT → AOT | Wasmer JIT → AOT |
|----------------------|--------------------|------------------|
| Cold Start           | 1.224s → 1.152s     | 1.194s → 1.364s  |
| Warm Loop Time       | 118.53s → 104.03s   | 117.02s → 102.83s|
| Max Memory (kB)      | 142,820 → 110,464   | 222,512 → 238,720|
| Binary Size (bytes)  | ~28.4M → ~40.5M     | ~28.4M → ~44.0M  |
| Throughput (r/s)     | 0.84 → 1.14         | 0.78 → 1.26      |

**Final Remarks:**  
AOT compilation brings **modest performance and memory benefits** for Wasmtime and a **notable throughput gain** for Wasmer. However, binary size increases significantly, and cold start times remain mostly unaffected. For high-throughput applications, AOT helps close the gap — but native execution continues to lead in all categories.

## Next Steps

- Profile real-world inputs with larger image sizes or model variants.
- Log startup latency and memory usage in real deployment conditions.

# WebAssembly Runtime Comparison and Performance Notes

## Why the WASM Binary is Slower

When comparing a native Rust binary to its WebAssembly (WASM) equivalent running under a runtime like `wasmtime` or `wasmer`, it's expected that the WASM version will be noticeably slower. This performance difference comes from several architectural and runtime factors.

WASM runtimes like `wasmtime` must parse, validate, and JIT-compile the WebAssembly binary at runtime, which adds overhead during execution. In contrast, native Rust binaries are compiled directly to machine code ahead of time with full optimizations enabled by `cargo build --release`, resulting in faster and more efficient execution.

Another factor is WASI, the WebAssembly System Interface. WASI provides a standardized set of system APIs that allow WASM programs to perform operations like reading files, accessing environment variables, or working with standard input and output. While this abstraction makes WASM portable and secure, it introduces additional layers between the program and the actual system calls, making I/O operations slower than native equivalents.

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

JIT warm-up time also plays a role. WASM runtimes typically compile code just-in-time as it's needed. This means the first few invocations of a function will include the cost of compiling that function, which increases the runtime of short-lived processes or cold starts.

Finally, WASM's memory model contributes to slower performance. It uses a linear memory with strict bounds checking on every access to ensure safety. Native Rust code, on the other hand, can perform unchecked or highly optimized memory operations when compiled in release mode, which gives it a significant speed advantage in memory-intensive workloads.

## Is This a Problem?

It depends on the goal:

- For deployment in a WebAssembly runtime (e.g., serverless platforms, browsers, or sandboxed plugin systems), this performance overhead is acceptable and expected.
- For performance-critical workloads, native Rust is significantly faster. WASM is best suited for portability, isolation, and safety.

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
