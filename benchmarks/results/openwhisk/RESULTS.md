```json
[
  {
    "run": 1,
    "activationId": "28139d03981c4a76939d03981cca7690",
    "kind": "blackbox",
    "memory": 512,
    "concurrency": 1,
    "initTime": 8130,
    "duration": 8511,
    "waitTime": 2330,
    "confidence": 0.6041240692138672,
    "label": "hen",
    "status": "success"
  },
  {
    "run": 2,
    "activationId": "71b879d4d2404d48b879d4d240fd486e",
    "kind": "wasm:0.1",
    "memory": 256,
    "concurrency": 1,
    "initTime": 1044,
    "duration": 2110,
    "waitTime": 224,
    "confidence": 0.6030619144439697,
    "label": "hen",
    "status": "success"
  }
]

```
# Analysis of Two `cold-start-test-mobilenet` Runs

This document provides a comparative analysis of two cold start executions of the `mobilenet_native_rust1` function using the `cargo run` command. The key differences lie in execution environment (`blackbox` vs `wasm`), memory usage, and cold start metrics like init time and duration.

---

## Summary Table

| Metric            | Run #1 (`blackbox`)        | Run #2 (`wasm:0.1`)         |
|------------------|----------------------------|-----------------------------|
| **Memory**        | 512 MB                     | 256 MB                      |
| **Concurrency**   | 1                          | 1                           |
| **Init Time**     | 8130 ms                    | 1044 ms                     |
| **Wait Time**     | 2330 ms                    | 224 ms                      |
| **Duration**      | 8511 ms                    | 2110 ms                     |
| **Confidence**    | 0.6041                     | 0.6031                      |
| **Label**         | "hen"                      | "hen"                       |
| **Status**        | success                    | success                     |

---

## Observations

### 1. **Execution Environment**
- **Run #1** executed in a `blackbox` containerized environment.
- **Run #2** executed using `wasm:0.1`, a WebAssembly-based runtime likely optimized for faster cold starts.

### 2. **Cold Start Metrics**
- **Run #1** had a very high `initTime` of 8130 ms compared to only 1044 ms in **Run #2**.
- Total `duration` of the function dropped from 8511 ms to 2110 ms — a nearly **4x improvement**.

### 3. **Memory and Efficiency**
- Despite having **half the memory** (256 MB vs 512 MB), **Run #2** outperformed the blackbox run, indicating better efficiency of the WASM environment.

### 4. **Prediction Output**
- Both runs predicted the same label `"hen"` with very similar confidence scores (~0.604).
- This confirms output consistency across environments.

### 5. **Latency**
- `waitTime` dropped significantly from 2330 ms in Run #1 to just 224 ms in Run #2, showing much faster request handling in the WASM environment.

---

## Conclusion

- **Run #2** using `wasm:0.1` is clearly **more performant and resource-efficient**.
- WebAssembly runtimes provide **lower cold start latency**, **lower memory requirements**, and **equivalent output quality** compared to traditional containerized `blackbox` executions.
- For serverless ML inference tasks like MobileNet, WASM appears to be the **preferred deployment strategy** when performance and efficiency are critical.

---

Run set 2:

results wasm openwhisk mobilenet model:
[{'concurrency': 1, 'count': 1, 'avg_init': 1038, 'max_wait': 296, 'avg_duration': 2154, 'avg_total': 2450}, {'concurrency': 2, 'count': 2, 'avg_init': 1149, 'max_wait': 271, 'avg_duration': 1715.5, 'avg_total': 1860}, {'concurrency': 3, 'count': 3, 'avg_init': 1047, 'max_wait': 268, 'avg_duration': 1542.33, 'avg_total': 1641.33}, {'concurrency': 4, 'count': 4, 'avg_init': 1216, 'max_wait': 324, 'avg_duration': 1469.5, 'avg_total': 1567.75}, {'concurrency': 5, 'count': 5, 'avg_init': 1130, 'max_wait': 1320, 'avg_duration': 1485.2, 'avg_total': 1768.8}]

results vanilla docker openwhisk mobilenet model:
[{'concurrency': 1, 'count': 1, 'avg_init': 8567, 'max_wait': 2459, 'avg_duration': 8950, 'avg_total': 11409}, {'concurrency': 2, 'count': 2, 'avg_init': 8661, 'max_wait': 2748, 'avg_duration': 4719, 'avg_total': 6099}, {'concurrency': 3, 'count': 3, 'avg_init': 8860, 'max_wait': 14832, 'avg_duration': 6314.33, 'avg_total': 12260.67}, {'concurrency': 4, 'count': 4, 'avg_init': 8358, 'max_wait': 35518, 'avg_duration': 8748.25, 'avg_total': 27562}]

# 🧪 OpenWhisk Mobilenet Cold Start Performance: WASM vs Docker (Blackbox)

This document compares cold start performance of the MobileNet model deployed on **Apache OpenWhisk**, executed via:

- **WASM runtime** (e.g., `wasm:0.1`)
- **Vanilla Docker / Blackbox runtime** (e.g., `blackbox`)

The metrics were measured for varying levels of **concurrent invocations**, from 1 to 5.

---

## 📊 Summary Table

| Concurrency | Runtime | Avg Init Time (ms) | Max Wait Time (ms) | Avg Duration (ms) | Avg Total Time (Wait + Duration, ms) |
|-------------|---------|--------------------|---------------------|-------------------|--------------------------------------|
| 1           | WASM    | 1038               | 296                 | 2154              | 2450                                 |
| 1           | Docker  | 8567               | 2459                | 8950              | 11409                                |
| 2           | WASM    | 1149               | 271                 | 1715.5            | 1860                                 |
| 2           | Docker  | 8661               | 2748                | 4719              | 6099                                 |
| 3           | WASM    | 1047               | 268                 | 1542.33           | 1641.33                              |
| 3           | Docker  | 8860               | 14832               | 6314.33           | 12260.67                             |
| 4           | WASM    | 1216               | 324                 | 1469.5            | 1567.75                              |
| 4           | Docker  | 8358               | 35518               | 8748.25           | 27562                                |
| 5           | WASM    | 1130               | 1320                | 1485.2            | 1768.8                               |
| 5           | Docker  | —                  | —                   | —                 | —                                    |

> Note: Docker data for concurrency 5 was not available.

---

## 🔍 Key Insights

### ✅ WASM Runtime Is Significantly Faster
- WASM cold start times (`initTime`) are **consistently ~1s**, compared to **8–9s** in Docker.
- The `avg_total` time (what a user would experience) is **up to 7x faster** in WASM at high concurrency:
  - At 4 concurrent requests: `WASM = 1.57s`, `Docker = 27.56s`

### 🔁 Docker Wait Times Spiral at Higher Loads
- `max_wait` in Docker reaches **35 seconds** at concurrency 4 — suggesting **severe resource contention or scheduling delay**.
- In contrast, WASM stays under **1.5 seconds**, even at 5 concurrent requests.

### 🔄 WASM Duration Improves With Concurrency
- WASM's `avg_duration` drops from ~2.1s at 1 request to ~1.5s at higher concurrency — indicating **better reuse or warm execution** patterns.

### ⚠️ Docker Duration Increases at Higher Loads
- `avg_duration` rises significantly from 4.7s (2 reqs) to 8.7s (4 reqs), possibly due to **container contention or cold starts** under load.

---

## 📈 Performance Trend Overview

- **WASM** scales linearly and remains low-latency under pressure.
- **Docker/Blackbox** becomes exponentially slower as concurrency rises.

---

## 🧩 Recommendations

1. ✅ **Prefer WASM for ML inference** in OpenWhisk when available — it provides faster cold starts and lower tail latencies.
2. 🛠️ Consider **reworking Docker-based runtimes** to reduce init overhead and improve concurrency handling.
3. 🔄 For Docker, **warmup strategies** (e.g., periodic pinging) may reduce painful cold starts under load.
4. 📉 If concurrency > 2 is expected, **avoid blackbox unless necessary** — the performance degradation is significant.

---

## 📌 Conclusion

WASM delivers **order-of-magnitude better performance** than Docker-based `blackbox` runtimes for cold start-heavy serverless inference workloads. It should be the default choice when cold start latency and scalability matter.

---
