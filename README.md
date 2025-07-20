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

To build openwhisk wasm binary:
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

```
>_ wsk action create mobilenet_docker mobilenet-oc-l-ow-wrapper.rs --docker vuckale/mobilenet-oc-l --memory 512
>_ wsk action invoke mobilenet_docker --param-file ./benchmarks/inputs/cat1.json --result --blocking
{
    "body": "Mobilenet output:\n{\n  \"confidence\": 0.3991692364215851,\n  \"label\": \"trolleybus, trolley coach, trackless trolley\"\n}\n"
}

docker login
docker push
run container
>_ docker run vuckale/mobilenet-oc-l
and attach 
>_ docker exec -it vuckale/mobilenet-oc-l bash

wasm:
wsk action create --kind wasm:0.1 mobilenet_wasm ./bin/mobilenet-oc-wasmtime.zip
wsk action invoke mobilenet_wasm --param-file ./benchmarks/inputs/cat1.json --result --blocking

>_ docker build -t vuckale/mobilenet-oc-add-l .

>_ wsk action create add '/home/aleksandar/Videos/forks/ow-wasm-mobilenet/ow-docker-runtime/add-wrapper.rs' --docker vuckale/mobilenet-oc-add-l
wsk action invoke mobilenet_native_rust --param-file input.json --result --blocking


kind cluster
helm install owdev .   -n openwhisk   --create-namespace   -f ../../deploy/kind/mycluster.yaml
(/home/aleksandar/openwhisk-deploy-kube)
>_ helm upgrade owdev ./helm/openwhisk   -n openwhisk   -f ./deploy/kind/mycluster.yaml
>_ kubectl get pods -n openwhisk 

>_ cat deploy/kind/mycluster.yaml 
whisk:
  ingress:
    type: NodePort
    apiHostName: localhost
    apiHostPort: 31001
    useInternally: false

nginx:
  httpsNodePort: 31001

# disable affinity
affinity:
  enabled: false
toleration:
  enabled: false

invoker:
  options: "-Dwhisk.kubernetes.user-pod-node-affinity.enabled=false"
  # must use KCF as kind uses containerd as its container runtime
  containerFactory:
    impl: "kubernetes"

invoke with wsk -i

APIHOST=http://172.17.0.1:3233
```

# Using MobileNetV2 in Serverless Environments: A Hybrid Deployment with Docker and WebAssembly

This essay explores the application of the pre-trained TensorFlow model `mobilenet_v2_1.4_224_frozen.pb` for image classification within a hybrid serverless architecture. We examine how this model is executed in both a Docker-based environment and a WebAssembly-based (Wasm) runtime using OpenWhisk, highlighting implementation strategies, performance implications, and architectural rationale.

## Understanding the Model: `mobilenet_v2_1.4_224_frozen.pb`

This file is a frozen Protocol Buffer (`.pb`) version of the MobileNetV2 model with:
- **Width multiplier**: `1.4`, meaning more filters for higher accuracy.
- **Input size**: `224x224`, common in mobile applications.
- **Frozen state**: the model is pre-optimized for inference with no trainable variables.

MobileNetV2 is well-suited for edge inference due to its small size and computational efficiency, making it ideal for environments like Wasm containers and resource-constrained devices.

## Docker-based Execution

A Rust binary, compiled for native execution, uses the `tract_tensorflow` crate to run the model:
- Reads a base64-encoded image from `stdin`.
- Decodes, resizes, and normalizes the image.
- Loads the model from embedded bytes using `include_bytes!`.
- Performs inference and returns the top label and its confidence score.

This binary is wrapped in a lightweight HTTP-compatible wrapper that:
- Accepts JSON input.
- Pipes it to the `mobilenet-oc-l` binary.
- Captures and returns the stdout result.
- Supports a quick ping for liveness checking.

This approach is optimized for maximum inference performance but suffers from Docker's cold start latency.

## WebAssembly (Wasm) Execution

For faster cold starts, the same inference pipeline is compiled to WebAssembly. Key changes:
- The Rust function is wrapped using the `ow_wasm_action_mobilenet_oc` macro, which adapts JSON input/output for the OpenWhisk-Wasm environment.
- The same image preprocessing, model loading, and inference steps are used.
- The model and labels are still statically embedded via `include_bytes!` and `include_str!`.

While WebAssembly introduces some runtime overhead and lacks certain features like asynchronous I/O (for now), its lightweight isolation and near-native startup latency make it ideal for handling initial (cold start) invocations.

## The Hybrid Approach: Fast Cold Starts, Strong Throughput

The deployment strategy takes advantage of both worlds:
- **WebAssembly** handles initial requests during cold starts because it can instantiate and execute rapidly.
- **Docker** takes over after its container is ready, offering better sustained throughput and higher ML performance under load.

This hybrid model is particularly valuable in latency-sensitive workloads (e.g. image APIs, mobile backends) where even hundreds of milliseconds can impact UX.

## Summary

- The `mobilenet_v2_1.4_224_frozen.pb` model is a mobile-optimized CNN ideal for serverless ML.
- Docker provides peak runtime performance but suffers cold start delays.
- WebAssembly offers fast cold starts and reasonable performance for warm-up bridging.
- A hybrid model mitigates cold start latency while preserving performance benefits.

This setup illustrates a practical, efficient way to run ML models in modern serverless environments by dynamically switching execution backends based on readiness and resource availability.

# Docker and WebAssembly Deployment for MobileNetV2 in OpenWhisk

This section outlines the deployment strategy for executing the `mobilenet_v2_1.4_224_frozen.pb` model within Apache OpenWhisk, using both Docker-based and WebAssembly-based runtimes. We explain the rationale for configuration choices such as memory limits and binary packaging.

---

## Docker-Based Action

The Docker action is created from a custom image based on the `openwhisk/action-rust-v1.34` base. The key steps are:

```dockerfile
FROM openwhisk/action-rust-v1.34
RUN rustup default 1.83.0

WORKDIR /action
COPY . .

RUN cargo build --release --example mobilenet-oc-l
RUN cp target/release/examples/mobilenet-oc-l /mobilenet-oc-l

WORKDIR /
```

This image:
- Compiles the `mobilenet-oc-l` binary statically using Cargo.
- Installs it to the container root for direct execution by OpenWhisk.
- Is pushed to Docker Hub and referenced as a custom runtime.

The action is created with:
```bash
wsk action create mobilenet_docker mobilenet-oc-l-ow-wrapper.rs --docker vuckale/mobilenet-oc-l --memory 512
```

### Why `--memory 512`?

The `--memory 512` flag sets the maximum memory (in MB) that OpenWhisk allocates to this action container. This is necessary because:

- The model itself (`mobilenet_v2_1.4_224_frozen.pb`) is ~16–30 MB in size.
- Inference with `tract_tensorflow` allocates:
  - Tensor storage
  - Intermediate buffers
  - Image decoding and resizing memory
- Image preprocessing (especially with RGB conversion and normalization) uses several `Vec<f32>` allocations.
- Conservative baseline testing showed that <256 MB sometimes leads to out-of-memory errors under concurrent invocations or slightly larger base64 images.

Thus, **512 MB is chosen as a safe minimum** for robust and stable inference.

---

## WebAssembly-Based Action

For fast cold start performance, the same model and logic are compiled into a Wasm binary and packaged like so:

```bash
wsk action create --kind wasm:0.1 mobilenet_wasm ./bin/mobilenet-oc-wasmtime.zip
```

- The `.zip` contains the precompiled WebAssembly `.wasm` binary along with metadata.
- `--kind wasm:0.1` tells OpenWhisk to use the WebAssembly runtime, specifically a WASI-enabled environment.
- The Wasm action handles quick inference during cold start bridging.

---
