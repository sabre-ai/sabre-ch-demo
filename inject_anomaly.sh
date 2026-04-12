#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="otel-demo"

AVAILABLE_ANOMALIES=(
  "recommendationCacheFailure"
  "paymentFailure"
  "productCatalogFailure"
  "paymentCacheLeak"
)

usage() {
  echo "Usage: $0 <anomaly_name>"
  echo ""
  echo "Available anomalies:"
  for a in "${AVAILABLE_ANOMALIES[@]}"; do
    echo "  - $a"
  done
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

ANOMALY="$1"

# Validate anomaly name
VALID=false
for a in "${AVAILABLE_ANOMALIES[@]}"; do
  if [[ "$a" == "$ANOMALY" ]]; then
    VALID=true
    break
  fi
done

if [[ "$VALID" != "true" ]]; then
  echo "ERROR: Unknown anomaly '${ANOMALY}'"
  echo ""
  usage
fi

echo "=== Injecting anomaly: ${ANOMALY} ==="

# Verify flagd ConfigMap exists
if ! kubectl get configmap flagd-config -n "${NAMESPACE}" &>/dev/null; then
  echo "ERROR: flagd-config ConfigMap not found in namespace '${NAMESPACE}'."
  echo "  Is the OTel demo deployed? Run ./setup.sh first."
  exit 1
fi

# Detect the flagd config key (varies by chart version)
FLAGD_KEY=$(kubectl get configmap flagd-config -n "${NAMESPACE}" -o json | jq -r '.data | keys[]' | head -1)

# Patch flagd ConfigMap to enable the feature flag
kubectl get configmap flagd-config -n "${NAMESPACE}" -o json \
  | jq --arg flag "$ANOMALY" --arg key "$FLAGD_KEY" '
    .data[$key] = (
      .data[$key] | fromjson
      | .flags[$flag].state = "ENABLED"
      | .flags[$flag].defaultVariant = "on"
      | tojson
    )
  ' \
  | kubectl apply -f -

# Restart flagd to pick up changes
kubectl rollout restart deployment/flagd -n "${NAMESPACE}" 2>/dev/null \
  || kubectl rollout restart deployment/otel-demo-flagd -n "${NAMESPACE}" 2>/dev/null \
  || echo "WARNING: Could not find flagd deployment. You may need to restart it manually."

echo ""
echo "Anomaly '${ANOMALY}' injected."
echo "Wait 5-10 minutes for telemetry to accumulate, then investigate with SABRE."
