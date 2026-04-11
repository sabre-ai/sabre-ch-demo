# SABRE + ClickHouse Demo: AI-Powered Root Cause Analysis

## Video Title
**"From Alert to Root Cause in 60 Seconds — SABRE x ClickHouse"**

---

## Pre-Recording Checklist

```bash
# 1. Start ClickHouse (Docker)
docker run -d --name ch-demo -p 9000:9000 -p 8123:8123 \
  -e CLICKHOUSE_USER=default -e CLICKHOUSE_PASSWORD= \
  -e CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1 \
  clickhouse/clickhouse-server:25.3-alpine

# 2. Create OTel tables (run once)
# Use the table creation SQL from setup.sh or run:
# cd sabre-ch-demo && ./setup.sh   (if using kind cluster)

# 3. Verify SABRE is installed and cloud mode works
sabre --cloud

# 4. Have two terminal windows ready:
#    - Terminal 1: for running commands
#    - Terminal 2: SABRE session viewer (http://localhost:8011)

# 5. Browser tab open to session viewer for showing execution tree
```

---

## SCENE 1: The Hook (15 seconds)

### On Screen
Terminal with a PagerDuty-style alert:

```
ALERT: Recommendation service — p99 latency > 5s
Affected: /api/recommendations
Duration: 12 minutes and counting
Impact: Users cannot see product recommendations
```

### Talking Points
> "It's 2 AM. You get paged. The recommendation service is timing out."
>
> "You have ClickHouse full of observability data — millions of log lines, traces, metrics. But where do you even start?"
>
> "What if your AI agent could investigate this for you — querying the actual data, following the evidence, and delivering a root cause analysis in under a minute?"

---

## SCENE 2: The Problem (30 seconds)

### On Screen
Split screen showing:
- Left: ClickHouse query console with raw data (overwhelming)
- Right: ChatGPT conversation trying to debug (generic advice)

### Talking Points
> "Here's the problem. ClickHouse has the data — logs, traces, metrics — all structured with OpenTelemetry."
>
> "But if you just dump logs into ChatGPT, you get generic advice: 'check your memory settings', 'look at your connection pool'. It doesn't actually query your data. It guesses."
>
> "ClickHouse's own research confirmed this: naive LLM prompts fail at root cause analysis. The bottleneck isn't the model — it's the missing domain knowledge and the inability to iteratively investigate."
>
> "That's exactly what SABRE solves."

---

## SCENE 3: What is SABRE (20 seconds)

### On Screen
Architecture diagram (simple):
```
User: "Investigate the recommendation service"
         |
    [ SABRE Agent ]
         |
   Query ClickHouse ──> Analyze results ──> Query again ──> Correlate ──> RCA
   (logs)                                    (traces)        (metrics)
```

### Talking Points
> "SABRE is an AI investigation agent. It doesn't just talk — it acts."
>
> "When you describe an incident, SABRE executes real queries against your ClickHouse, analyzes the results, and iteratively drills deeper — just like a senior SRE would."
>
> "It knows OpenTelemetry schemas, ClickHouse SQL patterns, and follows a structured investigation methodology: scope, survey, drill, trace, correlate, conclude."

---

## SCENE 4: Live Demo — Inject the Failure (15 seconds)

### Commands to Run

```bash
# Inject the anomaly (show this on screen)
./inject_anomaly.sh recommendationCacheFailure

# Seed realistic telemetry data (instant, no waiting)
./seed_data.sh recommendationCacheFailure
```

### On Screen
Terminal output showing:
```
=== Injecting anomaly: recommendationCacheFailure ===
Anomaly 'recommendationCacheFailure' injected.

=== Seeding data for anomaly: recommendationCacheFailure ===
  Inserting logs...
  Inserting traces...
  Inserting metrics...

=== Seed Complete ===
  Logs:    64 rows
  Traces:  66 rows
  Metrics: 25 rows

Ready for SABRE investigation. No waiting needed.
```

### Talking Points
> "We've just injected a real failure scenario — the recommendation service's cache is failing, causing memory pressure."
>
> "ClickHouse now has logs, traces, and metrics from this incident. Let's hand it to SABRE."

---

## SCENE 5: Live Demo — SABRE Investigates (90 seconds)

### Command to Run

```bash
sabre
```

Then type:

```
users are complaining that product recommendations are timing out.
can you check the clickhouse observability data and figure out what's going on?
```

### What the Audience Will See

SABRE will:

1. **Auto-load the ClickHouse integration** (no setup needed — trigger keywords activate it)

2. **Discover services:**
   ```
   > Bash.execute("clickhouse client --port 9000 --query 'SELECT DISTINCT ServiceName FROM otel_logs'")
   checkout
   frontend
   payment
   recommendation
   ```

3. **Find the error hotspot:**
   ```
   > Bash.execute("clickhouse client --query 'SELECT ServiceName, countIf(SeverityText=ERROR)...'")
   recommendation    18 errors / 26 total    69.23%
   payment           0 / 10                  0%
   frontend          0 / 20                  0%
   ```

4. **Measure latency:**
   ```
   > Bash.execute("clickhouse client --query 'SELECT ... quantile(0.95)(Duration/1e6)...'")
   recommendation  ListRecommendations  p95 = 8,600ms
   ```

5. **Check memory metrics:**
   ```
   > Bash.execute("clickhouse client --query 'SELECT ... Value FROM otel_metrics_gauge...'")
   recommendation  349MB → 510MB → 671MB → 832MB → 1,024MB   (climbing!)
   ```

6. **Drill into errors:**
   ```
   > Bash.execute("clickhouse client --query 'SELECT Body FROM otel_logs WHERE ServiceName=recommendation AND SeverityText=ERROR...'")
   java.lang.OutOfMemoryError: Java heap space - GC overhead limit exceeded
   Connection timeout to product-catalog service after 5000ms
   ```

7. **Deliver RCA:**
   > "The recommendation service is experiencing a memory leak. JVM heap usage climbed from 349MB to 1GB over 30 minutes. This caused OutOfMemoryErrors, which led to GC overhead, connection timeouts to downstream services, and ultimately 504s at the frontend."

### Talking Points (narrate as SABRE works)
> "Watch what happens. SABRE automatically loaded the ClickHouse integration — I didn't configure anything."
>
> "First, it discovers what services exist. No assumptions."
>
> "Now it's checking error rates across all services. Look — recommendation is at 69% errors while everything else is clean."
>
> "It's drilling into latency. 8.6 seconds p95 — that's your timeout."
>
> "Now this is the key part — it's checking memory metrics. See the JVM heap climbing? 349 megabytes to over a gigabyte in 30 minutes. That's your memory leak."
>
> "And there's the smoking gun — OutOfMemoryError in the logs."
>
> "In under a minute, SABRE queried logs, traces, AND metrics, correlated the signals, and identified a memory leak as the root cause. No guessing. Every finding backed by actual data."

---

## SCENE 6: Why This Matters (30 seconds)

### On Screen
Side-by-side comparison:

```
Without SABRE                          With SABRE
─────────────────                      ──────────────────
1. Get paged                           1. Get paged
2. SSH into cluster                    2. Ask SABRE to investigate
3. kubectl logs (wall of text)         3. RCA in 60 seconds
4. Grep for errors                       - queried 3 signal types
5. Check Grafana dashboards              - correlated across services
6. Query ClickHouse manually             - identified memory leak
7. Cross-reference traces                - suggested remediation
8. Form hypothesis
9. Test hypothesis
10. Find root cause
    ⏱️ 30-60 minutes                     ⏱️ < 1 minute
```

### Talking Points
> "Without SABRE, this investigation takes 30 to 60 minutes. An experienced SRE, SSHing into the cluster, grepping logs, switching between Grafana and ClickHouse, manually correlating signals."
>
> "With SABRE, you describe the problem in plain English and get a root cause analysis in under a minute — backed by real data from your ClickHouse."
>
> "SABRE doesn't replace your SREs. It gives them superpowers."

---

## SCENE 7: Key Differentiators (20 seconds)

### On Screen
Three bullet points appearing one at a time:

1. **Iterative Investigation** — Not a one-shot prompt. SABRE queries, analyzes, queries again.
2. **Real Data, Not Guesses** — Every finding backed by actual ClickHouse query results.
3. **Zero Configuration** — Mention "ClickHouse" and the integration auto-loads. OTel schema built in.

### Talking Points
> "Three things make this different from any other AI tool."
>
> "First — iterative investigation. SABRE doesn't guess. It queries your data, reads the results, and decides what to query next. Just like a senior engineer would."
>
> "Second — real data. Every claim SABRE makes is backed by an actual SQL query result. You can see exactly what it queried and verify it."
>
> "Third — zero configuration. You don't set up schemas, connect databases, or write prompts. Say 'check ClickHouse' and the integration loads automatically with full OTel schema knowledge."

---

## SCENE 8: Close (10 seconds)

### On Screen
SABRE logo + links

### Talking Points
> "SABRE plus ClickHouse. From alert to root cause in 60 seconds."
>
> "Try it yourself — links in the description."

---

## Total Runtime: ~4 minutes

---

## Tips for Recording

1. **Increase terminal font size** to 18-20pt for readability
2. **Use a dark terminal theme** — SABRE's output looks best on dark backgrounds
3. **Pre-run the demo once** to ensure ClickHouse is warm and queries are fast
4. **Have the session viewer** (http://localhost:8011) open in a browser tab — briefly show the execution tree to reinforce the "iterative" point
5. **Don't speed up the SABRE investigation** — the real-time typing/thinking animation is part of the impact. Let the audience watch it work.
6. **If using gpt-4o-mini**: add a hint in your prompt like "query the otel_logs, otel_traces_trace_id_ts, and otel_metrics_gauge tables". Stronger models (gpt-4o, claude) follow the methodology without hints.

## Backup: If SABRE Takes a Wrong Turn

If the model queries `system.trace_log` instead of OTel tables, use this prompt instead:

```
use clickhouse integration. the recommendation service is timing out.
investigate using the otel_logs, otel_traces_trace_id_ts, and otel_metrics_gauge tables.
start with: SELECT DISTINCT ServiceName FROM otel_logs
```

## Quick Reset Between Takes

```bash
# Truncate all data
clickhouse client --port 9000 --multiquery --query "
TRUNCATE TABLE otel_logs; TRUNCATE TABLE otel_traces;
TRUNCATE TABLE otel_traces_trace_id_ts; TRUNCATE TABLE otel_metrics_gauge;"

# Re-seed
./seed_data.sh recommendationCacheFailure
```
