#!/usr/bin/env bash
# blue-agent deploy v2. Runs on Blue phone. Claude agents go back to their own Anthropic key and only non Claude models
# such as GPT use OpenRouter. Deploys the newest runner code and makes every agent play again right away.
set -e
SERVICE="blue-agent-api"
ROOT="$HOME/blue-agent"
[ -d "$ROOT/.git" ] || ROOT="$HOME/blue-agent-runner"
[ -d "$ROOT/.git" ] || { gh repo clone sudosilo/blue-agent "$HOME/blue-agent" -- -q; ROOT="$HOME/blue-agent"; }
git -C "$ROOT" pull -q --ff-only
cd "$ROOT"
railway link --project blue-agent --service "$SERVICE" --environment production >/dev/null
OLD=$(railway variables --service "$SERVICE" --kv 2>/dev/null | grep '^AGENT_KEYS=' | cut -d= -f2- || true)
RUNNOW=$(OLD="$OLD" node -e 'let o={};try{o=JSON.parse(process.env.OLD||"{}")}catch(e){};console.log(Object.keys(o).join(",")+",olive,"+Date.now())')
railway variables --service "$SERVICE" --set "OPENROUTER_FOR_CLAUDE=0" --set "OPENROUTER_FALLBACK=0" --set "RUN_NOW=$RUNNOW" >/dev/null
railway up --service "$SERVICE" --ci
echo "Claude agents now bill their own Anthropic key, and only GPT and other non Claude models use OpenRouter."
echo "ALL SET"
