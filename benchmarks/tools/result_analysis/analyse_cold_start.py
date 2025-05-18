import json
from statistics import mean

with open('input_wasm_prewarmed.json') as f:
    data = json.load(f)

summary = []
for entry in data:
    concurrency = entry["no_concurrent_requests"]
    init_times = []
    wait_times = []
    durations = []
    total_times = []

    for r in entry["responses"]:
        ann = {a["key"]: a["value"] for a in r["annotations"]}
        wait = ann.get("waitTime", 0)
        init = ann.get("initTime", None)
        duration = r.get("duration", 0)

        wait_times.append(wait)
        durations.append(duration)
        if init is not None:
            init_times.append(init)
        total_times.append(wait + duration)

    summary.append({
        "concurrency": concurrency,
        "count": len(entry["responses"]),
        "avg_init": round(mean(init_times), 2) if init_times else "N/A",
        "max_wait": max(wait_times),
        "avg_duration": round(mean(durations), 2),
        "avg_total": round(mean(total_times), 2),
    })

print(summary)
