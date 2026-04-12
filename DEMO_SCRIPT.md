# SABRE + ClickHouse Demo: AI-Powered Root Cause Analysis

## Video Title
**"From Incident to Root Cause in Under 3 Minutes — SABRE x ClickHouse"**

---

## Pre-Recording Setup (do this 30 minutes before recording)

```bash
# 1. Deploy the full demo environment
cd sabre-ch-demo
./setup.sh

# 2. Inject the anomaly and let real telemetry accumulate
./inject_anomaly.sh recommendationCacheFailure

# 3. Wait 10-15 minutes for real OTel data to flow through
#    Verify data is accumulating:
clickhouse client --port 9000 --query "SELECT count() FROM otel_logs"
clickhouse client --port 9000 --query "SELECT count() FROM otel_traces_trace_id_ts"

# 4. Verify SABRE is working
sabre --cloud
# Type: use clickhouse integration
# Confirm it loads, then exit

# 5. Have one terminal window ready, font size 18-20pt, dark theme
```

For a live meeting: do the setup and anomaly injection 15 minutes before the audience joins. The data will be warm when you start.

---

## SCENE 1: The Problem (30 seconds)

### On Screen
Just the SABRE terminal, ready for input.

### Talking Points
> "You're on call. Something's wrong with the recommendation service — users are seeing timeouts. You have ClickHouse full of OpenTelemetry data: logs, traces, metrics. Millions of rows across dozens of services."
>
> "Where do you start?"
>
> "ClickHouse actually tested this. They ran five frontier models — including GPT-4o and Claude — against exactly these kinds of observability scenarios. All of them failed at root cause analysis. Their conclusion wasn't that the models are dumb. It's that **the bottleneck is missing domain specialization** — the models don't know the OTel schemas, the SQL patterns, or the investigation methodology."
>
> "That's the gap SABRE fills."

---

## SCENE 2: What SABRE Does Differently (20 seconds)

### On Screen
Still the terminal. No slides, no diagrams — you're about to show it live.

### Talking Points
> "SABRE is an AI investigation agent. When you describe an incident, it doesn't give you generic advice. It executes real SQL queries against your ClickHouse, reads the results, decides what to query next, and keeps going until it finds the root cause."
>
> "Every query is visible. Every reasoning step is auditable. You can see exactly what it's doing and verify every claim."
>
> "Let me show you."

---

## SCENE 3: Live Investigation (2-3 minutes)

### Commands

Type into SABRE:

```
use clickhouse integration
```

Wait for it to load (you'll see the schema and methodology appear). Then type:

```
The recommendation service is slow and users are reporting timeouts. Investigate.
```

### What the Audience Will See

SABRE generates `<helpers>` code blocks with real SQL queries. **Call out the transparency as it happens.**

**Step 1 — Discovery** (SABRE discovers what services exist):
```python
<helpers>
Bash.execute("clickhouse client --port 9000 --query 'SELECT DISTINCT ServiceName FROM otel_logs ORDER BY ServiceName'")
</helpers>
```
```
checkout
frontend
payment
recommendation
```

> **Narrate:** "Look at this — it's not guessing which services exist. It's querying ClickHouse to discover them. You can see the exact SQL right here in the helpers block."

**Step 2 — Error analysis** (finds the hotspot):
```python
<helpers>
Bash.execute("""clickhouse client --port 9000 --query "
SELECT ServiceName, countIf(SeverityText='ERROR') AS errors, count() AS total,
  round(countIf(SeverityText='ERROR')/count()*100, 2) AS error_pct
FROM otel_logs WHERE Timestamp >= now() - INTERVAL 1 HOUR
GROUP BY ServiceName ORDER BY error_pct DESC
" """)
</helpers>
```
```
recommendation    18/26    69.23%
payment           0/10     0%
frontend          0/20     0%
```

> **Narrate:** "It surveyed error rates across every service. Recommendation is at 69% errors. Everything else is clean. Now watch — it's going to drill into that service."

**Step 3 — Latency** (quantifies the impact):
```python
<helpers>
Bash.execute("""clickhouse client --port 9000 --query "
SELECT ServiceName, SpanName, quantile(0.95)(Duration/1e6) AS p95_ms
FROM otel_traces_trace_id_ts WHERE Timestamp >= now() - INTERVAL 1 HOUR
GROUP BY ServiceName, SpanName ORDER BY p95_ms DESC LIMIT 10
" """)
</helpers>
```
```
recommendation  ListRecommendations  p95 = 8,600ms
```

> **Narrate:** "8.6 seconds p95 on the recommendation service. That's your timeout right there. But it doesn't stop here — it's checking memory metrics too."

**Step 4 — Memory metrics** (finds the smoking gun):
```python
<helpers>
Bash.execute("""clickhouse client --port 9000 --query "
SELECT ResourceAttributes['service.name'] AS service, TimeUnix, round(Value/1048576) AS mb
FROM otel_metrics_gauge
WHERE MetricName = 'process.runtime.jvm.memory.usage'
  AND ResourceAttributes['service.name'] = 'recommendation'
  AND TimeUnix >= now() - INTERVAL 1 HOUR
ORDER BY TimeUnix
" """)
</helpers>
```
```
recommendation  17:54  349 MB
recommendation  17:57  429 MB
recommendation  18:00  510 MB
recommendation  18:03  590 MB
recommendation  18:06  671 MB
recommendation  18:09  751 MB
recommendation  18:12  832 MB
recommendation  18:15  912 MB
recommendation  18:18  993 MB
recommendation  18:21  1024 MB
```

> **Narrate:** "This is the key. JVM heap memory climbing linearly from 349 megabytes to over a gigabyte in 30 minutes. That's a memory leak. And now it's drilling into the error logs to confirm."

**Step 5 — Error drill-down** (confirms the root cause):
```python
<helpers>
Bash.execute("""clickhouse client --port 9000 --query "
SELECT Body, count() AS cnt FROM otel_logs
WHERE ServiceName = 'recommendation' AND SeverityText = 'ERROR'
  AND Timestamp >= now() - INTERVAL 1 HOUR
GROUP BY Body ORDER BY cnt DESC LIMIT 5
" """)
</helpers>
```
```
java.lang.OutOfMemoryError: Java heap space    12
Connection timeout to product-catalog          6
```

**Step 6 — SABRE delivers the RCA:**

> "The recommendation service is experiencing a memory leak. JVM heap usage climbed from 349MB to 1GB over 30 minutes, causing OutOfMemoryErrors and GC overhead. This led to connection timeouts to downstream services and 504 Gateway Timeouts at the frontend."

> **Narrate:** "There's the root cause. Memory leak, OOM errors, cascading timeouts. And every single finding is backed by a real SQL query that you can see and verify. That's the difference — this isn't AI guessing. It's AI investigating."

---

## SCENE 4: Why This Matters (30 seconds)

### On Screen
Still the terminal with the completed investigation visible.

### Talking Points
> "That investigation just queried logs, traces, and metrics. It correlated across three signal types, identified a memory leak, and delivered a root cause — all in under 3 minutes."
>
> "Without SABRE, an SRE does this manually. SSH into the cluster, grep the logs, switch to Grafana, query ClickHouse, cross-reference trace IDs. That's 30 to 60 minutes on a good day."
>
> "Three things make this work."
>
> "**One — iterative investigation.** SABRE doesn't make one query and guess. It queries, reads the results, decides what to look at next, and keeps going. Just like a senior engineer."
>
> "**Two — full transparency.** Every helpers block shows you the exact SQL being executed. You can see every query, verify every result. This is auditable AI."
>
> "**Three — built-in domain knowledge.** SABRE knows the OTel schemas, the ClickHouse SQL patterns, and a structured investigation methodology. That's the domain specialization that ClickHouse's research showed was missing from frontier models."

---

## SCENE 5: Close (10 seconds)

### Talking Points
> "SABRE plus ClickHouse. From incident to root cause in under 3 minutes."

---

## Total Runtime: ~4 minutes

---

## Recording Notes

1. **No fake data.** Use real telemetry from the running OpenTelemetry demo app. Inject the anomaly 15 minutes before recording. For the video, cut the wait time in editing.
2. **No mock-ups.** No fake PagerDuty alerts, no ChatGPT screenshots. Everything shown is real and running.
3. **Call out the `<helpers>` blocks.** This is the trust moment. When SABRE shows a helpers block with SQL, pause and say "you can see the exact query right here." That's the differentiator.
4. **Use explicit trigger.** Type `use clickhouse integration` on camera. It's a visible moment that shows intent.
5. **CLI consistency.** Always `clickhouse client` (two words, no hyphen). Never `clickhouse-client`.
6. **Don't say "zero configuration."** It's low-config — you need `clickhouse client` installed, network access to ClickHouse, and you type the trigger command. That's simple, not zero.
7. **Timing.** Title says "under 3 minutes" — the actual investigation will take 2-3 minutes with `gpt-4o-mini`. Over-deliver on the promise, don't risk looking slow.
8. **Terminal font size** 18-20pt, dark theme. SABRE's output renders best on dark backgrounds.
9. **Don't speed up the investigation.** The real-time thinking and query execution is part of the impact. Let the audience watch it work.

## Reset Between Takes

```bash
# Clear anomaly and data
./clear_anomaly.sh
# Re-inject and wait for fresh telemetry
./inject_anomaly.sh recommendationCacheFailure
# Wait 10-15 minutes, then record
```
