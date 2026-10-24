#!/usr/bin/env bash
# blue-agent key switch v3. Runs on Blue phone. Puts the Blue phone API key on the blue-agent runner.
set -e
SERVICE="blue-agent-api"
ROOT="/data/data/com.termux/files/home/blue-agent"
[ -d "$ROOT" ] || ROOT="$HOME/blue-agent"
cd "$ROOT"
railway link --project blue-agent --service "$SERVICE" --environment production >/dev/null
echo ""
read -rsp "Paste the Blue phone Anthropic API key and press enter: " AK
echo ""
AK="$(printf '%s' "$AK" | tr -d '[:space:]')"
case "$AK" in sk-ant-*) ;; *) echo "That is not an Anthropic API key. It starts with sk-ant. Run this script again."; exit 1;; esac
railway variables --service "$SERVICE" --set "ANTHROPIC_API_KEY=$AK" >/dev/null
cd "$ROOT"
railway up --service "$SERVICE" --ci
API=$(railway domain list --service "$SERVICE" --json 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1 || true)
[ -n "$API" ] || API=$(railway domain --port 8080 --service "$SERVICE" --json 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1 || true)
for i in $(seq 1 30); do
  if curl -fs --max-time 10 "https://$API/health" | grep -q "\"anthropicKeyEndsWith\":\"${AK: -4}\""; then break; fi
  echo "waiting for the runner to come up with the new key..."
  sleep 10
done
echo ""
echo "The runner now bills the key ending in ${AK: -4}"
echo "SAVE THIS runner key ending: ${AK: -4}"
echo "ALL SET"
