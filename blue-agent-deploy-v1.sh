#!/usr/bin/env bash
# blue-agent deploy v1. Runs on Blue phone. Pulls the newest runner code, deploys it, and makes every agent play again right away.
set -e
SERVICE="blue-agent-api"
ROOT="$HOME/blue-agent"
[ -d "$ROOT/.git" ] || ROOT="$HOME/blue-agent-runner"
[ -d "$ROOT/.git" ] || { gh repo clone sudosilo/blue-agent "$HOME/blue-agent" -- -q; ROOT="$HOME/blue-agent"; }
git -C "$ROOT" pull -q --ff-only
cd "$ROOT"
railway link --project blue-agent --service "$SERVICE" --environment production >/dev/null
OLD=$(railway variables --service "$SERVICE" --kv 2>/dev/null | grep '^AGENT_KEYS=' | cut -d= -f2- || true)
RUNNOW=$(OLD="$OLD" node -e 'let o={};try{o=JSON.parse(process.env.OLD||"{}")}catch(e){};console.log(Object.keys(o).join(",")+","+Date.now())')
railway variables --service "$SERVICE" --set "RUN_NOW=$RUNNOW" >/dev/null
railway up --service "$SERVICE" --ci
echo "The runner is deployed and every agent is playing a turn now."
echo "ALL SET"
