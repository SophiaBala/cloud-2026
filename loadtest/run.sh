#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

LABEL="${1:-run-$(date +%Y%m%d-%H%M)}"
SCRIPT="${SCRIPT:-scenario.js}"
BASE_URL="${BASE_URL:-$(terraform -chdir=../infra output -raw app_url)}"
mkdir -p results

ARGS=(-e BASE_URL="$BASE_URL" -e LABEL="$LABEL")
for v in VUS THINK RAMP_UP STEADY RAMP_DOWN RATE; do
  [[ -n "${!v:-}" ]] && ARGS+=(-e "$v=${!v}")
done

echo "Target: $BASE_URL  script: $SCRIPT  label: $LABEL"
if command -v k6 >/dev/null; then
  k6 run "${ARGS[@]}" "$SCRIPT"
else
  docker run --rm -i --add-host=host.docker.internal:host-gateway --user "$(id -u):$(id -g)" -v "$PWD:/work" -w /work \
    grafana/k6:0.54.0 run "${ARGS[@]}" "$SCRIPT"
fi
