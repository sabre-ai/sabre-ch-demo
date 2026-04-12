#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="otel-demo"

ANOMALIES=(
  "recommendationCacheFailure"
  "paymentFailure"
  "productCatalogFailure"
  "paymentCacheLeak"
)

echo "=== Clearing all anomalies ==="

# Verify flagd ConfigMap exists
if ! kubectl get configmap flagd-config -n "${NAMESPACE}" &>/dev/null; then
  echo "ERROR: flagd-config ConfigMap not found in namespace '${NAMESPACE}'."
  echo "  Is the OTel demo deployed? Run ./setup.sh first."
  exit 1
fi

# Detect the flagd config key (varies by chart version)
FLAGD_KEY=$(kubectl get configmap flagd-config -n "${NAMESPACE}" -o json | jq -r '.data | keys[]' | head -1)

# Reset all feature flags to disabled
kubectl get configmap flagd-config -n "${NAMESPACE}" -o json \
  | jq --arg key "$FLAGD_KEY" '
    .data[$key] = (
      .data[$key] | fromjson
      | .flags = (.flags | to_entries | map(
          .value.state = "DISABLED"
          | .value.defaultVariant = "off"
        ) | from_entries)
      | tojson
    )
  ' \
  | kubectl apply -f -

# Restart flagd to pick up changes
kubectl rollout restart deployment/flagd -n "${NAMESPACE}" 2>/dev/null \
  || kubectl rollout restart deployment/otel-demo-flagd -n "${NAMESPACE}" 2>/dev/null \
  || echo "WARNING: Could not find flagd deployment. You may need to restart it manually."

echo ""
echo "All anomalies cleared. Feature flags reset to disabled."
