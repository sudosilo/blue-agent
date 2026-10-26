#!/usr/bin/env bash
# blue-agent key switch v5. Runs on Blue phone. Puts the pasted API key on the blue-agent runner and makes every agent play again right away.
set -e
SERVICE="blue-agent-api"
ROOT="$HOME/blue-agent"
[ -d "$ROOT/.git" ] || ROOT="$HOME/blue-agent-runner"
cd "$ROOT"
railway link --project blue-agent --service "$SERVICE" --environment production >/dev/null
echo ""
read -rsp "Paste the Anthropic API key for the runner and press enter: " AK
echo ""
AK="$(printf '%s' "$AK" | tr -d '[:space:]')"
case "$AK" in sk-ant-*) ;; *) echo "That is not an Anthropic API key. It starts with sk-ant. Run this script again."; exit 1;; esac
OLD=$(railway variables --service "$SERVICE" --kv 2>/dev/null | grep '^AGENT_KEYS=' | cut -d= -f2- || true)
RUNNOW=$(OLD="$OLD" node -e 'let o={};try{o=JSON.parse(process.env.OLD||"{}")}catch(e){};console.log(Object.keys(o).join(",")+","+Date.now())')
railway variables --service "$SERVICE" --set "ANTHROPIC_API_KEY=$AK" --set "RUN_NOW=$RUNNOW" >/dev/null
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
echo "Every agent on the runner is playing a turn now. Turns land on the test bed in a few minutes."
echo "ALL SET"
