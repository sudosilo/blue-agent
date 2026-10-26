#!/usr/bin/env bash
# blue-agent detailer v1. Runs on Blue phone. Moves the detailer agent onto the blue-agent runner.
# Usage: bash blue-agent-detailer-v1.sh DETAILERKEY
set -e
KEY="$(printf '%s' "${1:-}" | tr -d '[:space:]')"
case "$KEY" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;; *) echo "Give the detailer key after the script name."; exit 1;; esac
SERVICE="blue-agent-api"
ROOT="$HOME/blue-agent"
if [ -d "$ROOT/.git" ]; then
  git -C "$ROOT" pull -q --ff-only
else
  ROOT="$HOME/blue-agent-runner"
  if [ -d "$ROOT/.git" ]; then git -C "$ROOT" pull -q --ff-only; else gh repo clone sudosilo/blue-agent "$ROOT" -- -q; fi
fi
cd "$ROOT"
echo "Working in $(pwd)"
railway link --project blue-agent --service "$SERVICE" --environment production >/dev/null
OLD=$(railway variables --service "$SERVICE" --kv 2>/dev/null | grep '^AGENT_KEYS=' | cut -d= -f2- || true)
NEW=$(OLD="$OLD" KEY="$KEY" node -e 'let o={};try{o=JSON.parse(process.env.OLD||"{}")}catch(e){};o.detailer=process.env.KEY;console.log(JSON.stringify(o))')
railway variables --service "$SERVICE" --set "AGENT_KEYS=$NEW" >/dev/null
railway up --service "$SERVICE" --ci
API=$(railway domain list --service "$SERVICE" --json 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1 || true)
[ -n "$API" ] || API=$(railway domain --port 8080 --service "$SERVICE" --json 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1 || true)
for i in $(seq 1 30); do
  if curl -fs --max-time 10 "https://$API/health" | grep -q '"version":6'; then break; fi
  echo "waiting for the runner to come up as v6..."
  sleep 10
done
# the old copy of the detailer in steward-repo stands down so it never plays twice
gh variable set DETAILER_ON_BLUE --body 1 --repo sudosilo/steward-repo
echo ""
curl -s "https://$API/health"; echo ""
echo "The detailer now lives on the blue-agent runner and plays at 13:00 and 21:00 UTC."
echo "ALL SET"
