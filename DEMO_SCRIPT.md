# SABRE + ClickHouse Demo for ClickHouse Founders

## Video Title
**"From Incident to Root Cause in Under 3 Minutes — SABRE x ClickHouse"**

---

# Part 1: Pre-Warming the Demo

Do this 15-20 minutes before the meeting/recording. The goal is to have a running cluster with real telemetry flowing into ClickHouse so there's no setup or waiting during the presentation.

### Step 1: Deploy everything

```bash
cd sabre-ch-demo
./setup.sh
```

This creates a kind cluster with:
- Standalone ClickHouse (stores OTel data)
- OTel Collector bridge (receives OTLP, writes to ClickHouse)
- OpenTelemetry Demo app (16 microservices generating real telemetry)

Takes ~5-10 minutes. All pods should be Running at the end.

### Step 2: Port-forward ClickHouse

```bash
kubectl port-forward svc/clickhouse 9000:9000 &
```

### Step 3: Wait for data to accumulate

Wait 10-15 minutes. The OTel demo's load generator continuously sends traffic through the microservices, generating real logs, traces, and metrics.

Verify data is flowing:

```bash
clickhouse client --port 9000 --query "SELECT 'logs', count() FROM otel_logs"
clickhouse client --port 9000 --query "SELECT 'traces', count() FROM otel_traces"
clickhouse client --port 9000 --query "SELECT 'metrics', count() FROM otel_metrics_gauge"
```

All counts should be in the thousands. You should see 16 services:

```bash
clickhouse client --port 9000 --query "SELECT DISTINCT ServiceName FROM otel_logs ORDER BY ServiceName"
```

### Step 4: Verify SABRE works

```bash
sabre --cloud
> use clickhouse integration
```

Confirm the integration loads (you'll see the schema and methodology). Then type `exit`.

### Step 5: Verify there's something interesting to find

```bash
clickhouse client --port 9000 --query "
SELECT ServiceName, quantile(0.95)(Duration/1e6) AS p95_ms, count() AS spans
FROM otel_traces WHERE Timestamp >= now() - INTERVAL 30 MINUTE
GROUP BY ServiceName ORDER BY p95_ms DESC LIMIT 5"
```

You should see some services with high latency (accounting, product-reviews, load-generator typically show elevated p95). The OTel demo running on a kind cluster naturally exhibits performance variance — these are real issues, not injected.

### Step 6: Keep it warm

Leave the cluster running. When it's time to present, just open a terminal and start SABRE.

### If something goes wrong

```bash
# Check all pods are running
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Check bridge is forwarding data
kubectl logs deploy/otel-clickhouse-bridge --tail=5

# Re-establish port-forward if it dropped
pkill -f "kubectl port-forward svc/clickhouse"; sleep 1
kubectl port-forward svc/clickhouse 9000:9000 &

# Nuclear option: tear down and start over
./teardown.sh && ./setup.sh
```

---

# Part 2: The Presentation

Total runtime: ~4-5 minutes

---

## SCENE 1: Set the Stage (30 seconds)

### On Screen
Terminal, dark theme, font size 18-20pt. Nothing else.

### Say
> "Let me show you something. I have a microservices application running — 16 services, the OpenTelemetry demo app. It's generating real telemetry: logs, traces, metrics. All of it flowing into ClickHouse."
>
> "We've been getting reports that the app feels slow. Users are seeing latency. But we have 16 services — where do you even start?"
>
> "Your research showed that five frontier models, including GPT-4o, all failed at root cause analysis against observability data. The conclusion was that the bottleneck isn't model intelligence — it's missing domain specialization. The models don't know the OTel schemas, the query patterns, or how to systematically investigate."
>
> "We built SABRE to fill that gap. Let me show you what it looks like."

---

## SCENE 2: Start SABRE (15 seconds)

### Type

```
sabre
```

Wait for it to connect. Then type:

```
use clickhouse integration
```

### Say
> "I'm loading the ClickHouse integration. This gives SABRE the OTel table schemas, ClickHouse SQL patterns, and an investigation methodology — scope, survey, drill, correlate, conclude."

Pause briefly while it loads.

---

## SCENE 3: The Investigation (2-3 minutes)

### Type

```
There are reports of slow performance across our application. Investigate using the observability data in ClickHouse.
```

### What will happen

SABRE will generate `<helpers>` blocks containing real SQL queries. Each query executes against ClickHouse and the results feed into the next step. **This is the core of the demo — narrate what's happening as it works.**

**As SABRE discovers services:**
> "It's starting with a discovery query — finding out what services exist. No assumptions. It's querying your ClickHouse right now."

**As SABRE checks error rates:**
> "Now it's surveying error rates across all services. Look at the helpers block — you can see the exact SQL it's running. Every step is transparent and auditable."

**As SABRE analyzes latency:**
> "Here's where it gets interesting. It's pulling latency percentiles from the traces table. P50, P95, P99 for every service and span. Watch which services light up."

**When results show high latency services:**
> "Look at this — [service name] at [X] seconds p95. That's the kind of thing that would take an SRE 20 minutes of Grafana dashboard switching to find. SABRE found it in one query."

**As SABRE drills deeper:**
> "Now it's drilling into the problem. Checking the specific spans, looking at the request flow, pulling the error logs for that service. This is the iterative investigation — it queries, reads the results, decides what to look at next."

**When SABRE delivers findings:**
> "And there it is. It identified the slow services, quantified the latency, and correlated across logs, traces, and metrics. Every finding backed by a real query result from your ClickHouse."

---

## SCENE 4: The Takeaway (30 seconds)

### Say
> "Three things I want to highlight."
>
> "First — this was real data. Real application, real telemetry, real ClickHouse queries. Nothing staged."
>
> "Second — every step was visible. Those helpers blocks showed the exact SQL being generated and executed. An SRE can see what SABRE did, verify every claim, and learn from the investigation. This is auditable AI."
>
> "Third — the domain knowledge made the difference. SABRE knew to query `otel_traces` for latency percentiles, knew to use Map bracket syntax for resource attributes, knew to divide Duration by a million for milliseconds. That's the specialization your research said was missing from frontier models. We built it in."

---

## SCENE 5: Close (10 seconds)

### Say
> "SABRE plus ClickHouse. Real observability data, real investigations, real root cause analysis."

---

## Presentation Notes

**Things to emphasize:**
- "Real data" — say it multiple times. This isn't a canned demo.
- The `<helpers>` blocks are the trust moment. Point at them. "You can see the exact SQL."
- Reference their research. "This is the domain specialization your paper identified as the gap."

**Things NOT to say:**
- Don't say "zero configuration" — it's low-config, not zero.
- Don't say "60 seconds" — the investigation takes 2-3 minutes. Say "under 3 minutes."
- Don't say "replaces SREs" — say "gives SREs superpowers."

**What if SABRE finds something unexpected:**
That's fine — it's real data. If it finds an issue you didn't anticipate, that's actually more impressive. Roll with it: "I didn't even know about this one — SABRE found it from the data."

**What if SABRE makes a mistake:**
If it queries a wrong table or gets a SQL error, it will self-correct (query the schema, retry). Let it work through it. Say: "Watch this — it hit an error, now it's figuring out the correct schema. This is the iterative investigation in action."

**What if someone asks about the model:**
"SABRE works with any model — we're running gpt-4o-mini here. The investigation quality comes from the domain knowledge and the iterative execution loop, not from model size. A smaller model with the right specialization outperforms a frontier model without it."

## Teardown (after the meeting)

```bash
cd sabre-ch-demo
./teardown.sh
```
