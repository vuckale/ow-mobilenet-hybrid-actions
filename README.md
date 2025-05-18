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


>_ wsk action create mobilenet_native_rust1 mobilenet-oc-l-ow-wrapper.rs --docker vuckale/mobilenet-oc-l --memory 512
>_ wsk action invoke mobilenet_native_rust1 --param-file ./benchmarks/inputs/cat1.json --result --blocking
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
wsk action create --kind wasm:0.1 mobilenet_native_rust1 ./bin/mobilenet-oc-wasmtime.zip
wsk action invoke mobilenet_native_rust1 --param-file input.json --result --blocking

>_ docker build -t vuckale/mobilenet-oc-add-l .

>_ wsk action create add '/home/aleksandar/Videos/forks/ow-wasm-mobilenet/ow-docker-runtime/add-wrapper.rs' --docker vuckale/mobilenet-oc-add-l
wsk action invoke mobilenet_native_rust --param-file input.json --result --blocking

kind cluster
helm install owdev .   -n openwhisk   --create-namespace   -f ../../deploy/kind/mycluster.yaml
(/home/aleksandar/openwhisk-deploy-kube)
>_ helm upgrade owdev ./helm/openwhisk   -n openwhisk   -f ./deploy/kind/mycluster.yaml
>_ kubectl get pods -n openwhisk 

>_ cat deploy/kind/mycluster.yaml 
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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

