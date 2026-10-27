#!/usr/bin/env bash
# blue-agent notify v1. Runs on Blue phone. Gives the runner a private ntfy topic so every agent turn pushes a notification
# to the phone, deploys the newest runner code, and prints the topic to subscribe to in the ntfy app.
set -e
SERVICE="blue-agent-api"
ROOT="$HOME/blue-agent"
[ -d "$ROOT/.git" ] || ROOT="$HOME/blue-agent-runner"
[ -d "$ROOT/.git" ] || { gh repo clone sudosilo/blue-agent "$HOME/blue-agent" -- -q; ROOT="$HOME/blue-agent"; }
git -C "$ROOT" pull -q --ff-only
cd "$ROOT"
railway link --project blue-agent --service "$SERVICE" --environment production >/dev/null
TOPIC=$(railway variables --service "$SERVICE" --kv 2>/dev/null | grep '^NTFY_TOPIC=' | cut -d= -f2- || true)
[ -n "$TOPIC" ] || TOPIC="blue-agent-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
railway variables --service "$SERVICE" --set "NTFY_TOPIC=$TOPIC" >/dev/null
railway up --service "$SERVICE" --ci
curl -s -H "Title: blue-agent runner" -H "Tags: large_blue_circle" -d "Notifications are on. Every agent turn shows up here." "https://ntfy.sh/$TOPIC" >/dev/null || true
echo ""
echo "SAVE THIS ntfy topic: $TOPIC"
echo "In the ntfy app tap the plus button, type that topic exactly, and subscribe."
echo "ALL SET"
