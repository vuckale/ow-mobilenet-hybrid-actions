# Analysis of OpenWhisk Mobilenet Model Performance: Prewarmed Vanilla vs Prewarmed WASM
 
This document presents a comparison between two OpenWhisk configurations for running the Mobilenet model using **prewarmed containers**:
 
- **Vanilla**: A traditional containerized runtime.
- **WASM**: A WebAssembly-based runtime.
 
Each configuration consists of 5 runs with the same concurrency (1) and count (1). The key metrics compared are:
- `max_wait`: The maximum time the request waited before execution (ms).
- `avg_duration`: The average execution time of the function itself (ms).
- `avg_total`: The total average time including wait time and execution (ms).
 
---
 
## Summary of Metrics
 
| Metric        | Vanilla (ms) | WASM (ms) |
|---------------|--------------|-----------|
| Avg Max Wait  | 13.6         | 16.0      |
| Avg Duration  | 384.4        | 1012.6    |
| Avg Total     | 398.0        | 1024.6    |
 
---
 
## Observations
 
### 1. **Execution Duration**
- **Vanilla** shows an average execution time (`avg_duration`) of **~384 ms**.
- **WASM** is significantly slower, with an average of **~1013 ms**.
- This suggests that the WebAssembly runtime incurs roughly **2.6x slower inference performance** for the Mobilenet model.
 
### 2. **Total Time**
- The total time (`avg_total`) includes wait and execution.
- WASM's total time averages at **~1025 ms**, versus **~398 ms** for Vanilla, reinforcing the slower performance trend.
 
### 3. **Wait Times**
- Both configurations have relatively low wait times, but WASM has slightly higher average (`16 ms` vs `13.6 ms`).
- This is likely due to minor differences in container scheduling or internal runtime overhead but not the primary performance bottleneck.
 
---
 
## Conclusion
 
While both runtimes were **prewarmed** (no cold starts), the **WASM runtime performs significantly worse** than the Vanilla container in executing the Mobilenet model in OpenWhisk. Given the ~2.6x higher execution time, **WASM may not yet be suitable for latency-sensitive AI workloads** like Mobilenet inference unless performance is further optimized.
 
--- 
**Recommendation**: For real-time or low-latency scenarios, stick with the Vanilla runtime unless WASM offers other compelling benefits (e.g., portability, security, or startup time) that outweigh the execution delay.
