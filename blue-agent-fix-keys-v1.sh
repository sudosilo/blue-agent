#!/usr/bin/env bash
# blue-agent fix keys v1. Runs on Blue phone. Reloads every agent's test bed key on the runner from the test bed itself,
# makes those agents play again right away, redeploys, and prints how their newest runs went.
set -e
SERVICE="blue-agent-api"
TB="$HOME/2026-10-18-orange-testbed"
[ -d "$TB/.git" ] || gh repo clone sudosilo/2026-10-18-orange-testbed "$TB" -- -q
git -C "$TB" pull -q --ff-only
ROOT="$HOME/blue-agent"
[ -d "$ROOT/.git" ] || ROOT="$HOME/blue-agent-runner"
[ -d "$ROOT/.git" ] || gh repo clone sudosilo/blue-agent "$ROOT" -- -q
git -C "$ROOT" pull -q --ff-only
cd "$ROOT"
railway link --project blue-agent --service "$SERVICE" --environment production >/dev/null
VARS=$(railway variables --service "$SERVICE" --kv 2>/dev/null)
OLD=$(printf '%s\n' "$VARS" | grep '^AGENT_KEYS=' | cut -d= -f2- || true)
IDS=$(OLD="$OLD" node -e 'let o={};try{o=JSON.parse(process.env.OLD||"{}")}catch(e){};console.log(Object.keys(o).join(" "))')
[ -n "$IDS" ] || IDS="blue purple"
NEW="{}"
for ID in $IDS; do
  K=$(cd "$TB" && bash scripts/newkey.sh "$ID" | sed 's/.*SAVE THIS: //')
  case "$K" in ""|ERROR*) echo "No test bed key for $ID: $K"; continue;; esac
  NEW=$(NEW="$NEW" ID="$ID" K="$K" node -e 'const o=JSON.parse(process.env.NEW);o[process.env.ID]=process.env.K;console.log(JSON.stringify(o))')
  echo "Key reloaded for $ID"
done
RUNNOW=$(NEW="$NEW" node -e 'console.log(Object.keys(JSON.parse(process.env.NEW)).join(",")+","+Date.now())')
railway variables --service "$SERVICE" --set "AGENT_KEYS=$NEW" --set "RUN_NOW=$RUNNOW" >/dev/null
railway up --service "$SERVICE" --ci
API=$(railway domain list --service "$SERVICE" --json 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1 || true)
[ -n "$API" ] || API=$(railway domain --port 8080 --service "$SERVICE" --json 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1 || true)
for i in $(seq 1 30); do curl -fs --max-time 10 "https://$API/health" >/dev/null && break; sleep 10; done
echo ""
echo "Runner address, SAVE THIS: $API"
curl -s "https://$API/health"; echo ""
echo ""
echo "Newest runs before this restart:"
LOG=$( (timeout 45 railway logs --service "$SERVICE" 2>/dev/null || true) | grep '^RUN ' | head -10)
printf '%s\n' "$LOG"
echo ""
if printf '%s' "$LOG" | grep -qi 'credit balance\|billing\|insufficient'; then
  echo "VERDICT: the Anthropic API key on the runner is out of money. Add credit to that account or run blue-agent-key-switch-v4.sh with a funded key."
elif printf '%s' "$LOG" | grep -qi 'authentication_error\|invalid x-api-key\|401'; then
  echo "VERDICT: the Anthropic API key on the runner is dead. Run blue-agent-key-switch-v4.sh with a working key."
elif printf '%s' "$LOG" | grep -qi 'wrong key\|Unknown id\|403'; then
  echo "VERDICT: the test bed keys were stale. They are reloaded now and the agents are playing again."
else
  echo "VERDICT: keys reloaded and the agents are playing again now. Their turns land on the test bed in a few minutes."
fi
echo "ALL SET"
