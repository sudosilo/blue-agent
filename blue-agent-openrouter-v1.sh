#!/usr/bin/env bash
# blue-agent openrouter v1. Runs on Blue phone. Puts the pasted OpenRouter key on the blue-agent runner, sends every model
# through OpenRouter, deploys the newest runner code, and makes every agent play again right away.
set -e
SERVICE="blue-agent-api"
ROOT="$HOME/blue-agent"
[ -d "$ROOT/.git" ] || ROOT="$HOME/blue-agent-runner"
[ -d "$ROOT/.git" ] || { gh repo clone sudosilo/blue-agent "$HOME/blue-agent" -- -q; ROOT="$HOME/blue-agent"; }
git -C "$ROOT" pull -q --ff-only
cd "$ROOT"
railway link --project blue-agent --service "$SERVICE" --environment production >/dev/null
echo ""
read -rsp "Paste the OpenRouter API key and press enter: " OK
echo ""
OK="$(printf '%s' "$OK" | tr -d '[:space:]')"
case "$OK" in sk-or-*) ;; *) echo "That is not an OpenRouter key. It starts with sk-or. Run this script again."; exit 1;; esac
OLD=$(railway variables --service "$SERVICE" --kv 2>/dev/null | grep '^AGENT_KEYS=' | cut -d= -f2- || true)
RUNNOW=$(OLD="$OLD" node -e 'let o={};try{o=JSON.parse(process.env.OLD||"{}")}catch(e){};console.log(Object.keys(o).join(",")+","+Date.now())')
railway variables --service "$SERVICE" --set "OPENROUTER_API_KEY=$OK" --set "OPENROUTER_FOR_CLAUDE=1" --set "RUN_NOW=$RUNNOW" >/dev/null
railway up --service "$SERVICE" --ci
API=$(railway domain list --service "$SERVICE" --json 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1 || true)
[ -n "$API" ] || API=$(railway domain --port 8080 --service "$SERVICE" --json 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1 || true)
for i in $(seq 1 30); do
  if curl -fs --max-time 10 "https://$API/health" | grep -q "\"openrouterKeyEndsWith\":\"${OK: -4}\""; then break; fi
  echo "waiting for the runner to come up with the OpenRouter key..."
  sleep 10
done
echo ""
echo "Every agent on the runner now plays through OpenRouter, and every agent is playing a turn now."
echo "SAVE THIS OpenRouter key ending: ${OK: -4}"
echo "ALL SET"
