#!/usr/bin/env bash
# blue-agent detailer key v1. Runs on any phone with Railway. Gives the detailer its own Anthropic API key
# and deploys the newest runner code (detailer plays once a day at 13:00 UTC).
set -e
# Termux needs the resolv.conf bind or Railway cannot look up its own servers
RW="$(command -v railway)"
if [ -n "$PREFIX" ] && command -v proot >/dev/null; then railway(){ proot -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf" "$RW" "$@"; }; fi
SERVICE="blue-agent-api"
railway whoami >/dev/null 2>&1 || railway login --browserless </dev/tty
printf "Paste the Anthropic API key for the detailer, then press Enter: "
read -rs KEY </dev/tty; echo ""
KEY="$(printf '%s' "$KEY" | tr -d '[:space:]')"
case "$KEY" in sk-ant-*) ;; *) echo "That does not look like an Anthropic key (it starts with sk-ant-)."; exit 1;; esac
ROOT="$HOME/blue-agent"
[ -d "$ROOT/.git" ] || ROOT="$HOME/blue-agent-runner"
[ -d "$ROOT/.git" ] || { gh repo clone sudosilo/blue-agent "$HOME/blue-agent" -- -q; ROOT="$HOME/blue-agent"; }
git -C "$ROOT" pull -q --ff-only
cd "$ROOT"
railway link --project blue-agent --service "$SERVICE" --environment production >/dev/null
railway variables --service "$SERVICE" --set "ANTHROPIC_API_KEY_DETAILER=$KEY" >/dev/null
railway up --service "$SERVICE" --ci
echo "The detailer now bills its own key ending in ${KEY: -4} and plays once a day at 13:00 UTC."
echo "ALL SET"
