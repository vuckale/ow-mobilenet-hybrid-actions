# mobilenet-infer-benchmark

Run image classification with MobileNet in both WebAssembly and native Rust, using `tract` for inference. Designed to support performance comparisons between runtimes.

## Features

- MobileNet V2 inference using a frozen `.pb` model
- Inference powered by `tract-tensorflow`
- WebAssembly support with OpenWhisk-compatible interface

Build with Rust 1.83.0:

```bash
cargo build --release --example mobilenet-oc --target=wasm32-wasi --features=wasm
```

Then optimize it:

```bash
./optimize-target.sh
```

This produces the optimized and stripped WebAssembly binary: `mobilenet-oc-o.wasm`
