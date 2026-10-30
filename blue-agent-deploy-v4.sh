#!/usr/bin/env bash
# blue-agent deploy v4. Runs on any phone with Railway logged in. Deploys the newest runner code: the detailer plays once a day at 13:00 UTC.
set -e
# Termux needs the resolv.conf bind or Railway cannot look up its own servers
RW="$(command -v railway)"
if [ -n "$PREFIX" ] && command -v proot >/dev/null; then railway(){ proot -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf" "$RW" "$@"; }; fi
SERVICE="blue-agent-api"
ROOT="$HOME/blue-agent"
[ -d "$ROOT/.git" ] || ROOT="$HOME/blue-agent-runner"
[ -d "$ROOT/.git" ] || { gh repo clone sudosilo/blue-agent "$HOME/blue-agent" -- -q; ROOT="$HOME/blue-agent"; }
git -C "$ROOT" pull -q --ff-only
cd "$ROOT"
railway link --project blue-agent --service "$SERVICE" --environment production >/dev/null
railway up --service "$SERVICE" --ci
echo "The detailer now plays once a day at 13:00 UTC."
echo "ALL SET"
