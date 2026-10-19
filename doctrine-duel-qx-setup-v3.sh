#!/data/data/com.termux/files/usr/bin/bash
# doctrine-duel-qx setup v3. Safe to run again: it reuses everything that already exists.
set -e
ROOT="$HOME/doctrine-duel-qx"
SERVICE="doctrine-duel-qx-api"
gen(){ node -e 'console.log(require("crypto").randomBytes(24).toString("hex"))'; }

echo ""
echo "Step: test bed join code"
JOIN="${TESTBED_JOIN_CODE:-}"
echo ""
echo "Step: Anthropic key"
AK=""
LINKS=$(node -e 'try{const c=require(require("os").homedir()+"/.railway/config.json");for(const [p,v] of Object.entries(c.projects||{}))console.log(p+"\t"+(v.service||""))}catch(e){}')
while IFS="$(printf '\t')" read -r d s; do
  if [ -n "$AK" ] || [ ! -d "$d" ]; then continue; fi
  v=$(cd "$d" && railway variables --kv 2>/dev/null | grep '^ANTHROPIC_API_KEY=sk-ant' | head -1 | cut -d= -f2-)
  if [ -z "$v" ] && [ -n "$s" ]; then v=$(cd "$d" && railway variables --kv --service "$s" 2>/dev/null | grep '^ANTHROPIC_API_KEY=sk-ant' | head -1 | cut -d= -f2-); fi
  if [ -n "$v" ]; then AK="$v"; fi
done <<EOF
$LINKS
EOF
if [ -z "$AK" ]; then read -rp "Paste your Anthropic API key and press enter: " AK; fi

echo ""
echo "Step: Railway runner"
cd "$ROOT/doctrine-duel-qx-backend"
if ! railway status --json 2>/dev/null | grep -q '"doctrine-duel-qx"'; then railway init --name doctrine-duel-qx; fi
if ! railway status --json 2>/dev/null | grep -q '"doctrine-duel-qx"'; then echo "Railway did not link the doctrine-duel-qx project to this folder"; exit 1; fi
railway service list --json 2>/dev/null | grep -q '"Redis"' || railway add --database redis
railway service list --json 2>/dev/null | grep -q "\"$SERVICE\"" || railway add --service "$SERVICE" --variables PORT=8080
DASH=$(railway variables --service "$SERVICE" --kv 2>/dev/null | grep '^DASH_KEY=' | cut -d= -f2- || true)
[ -n "$JOIN" ] || JOIN=$(railway variables --service "$SERVICE" --kv 2>/dev/null | grep '^TESTBED_JOIN_CODE=' | cut -d= -f2- || true)
if [ -z "$JOIN" ]; then read -rp "Paste the test bed join code and press enter: " JOIN; fi
[ -n "$DASH" ] || DASH=$(gen)
railway variables --service "$SERVICE" \
  --set 'REDIS_URL=${{Redis.REDIS_URL}}' \
  --set "PORT=8080" \
  --set "DASH_KEY=$DASH" \
  --set "ANTHROPIC_API_KEY=$AK" \
  --set "GH_TOKEN=$(gh auth token)" \
  --set "TESTBED_JOIN_CODE=$JOIN" >/dev/null
railway up --service "$SERVICE" --ci
API=$(railway domain --port 8080 --service "$SERVICE" --json 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1 || true)
[ -n "$API" ] || API=$(railway domain list --service "$SERVICE" --json 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1 || true)
for i in $(seq 1 30); do
  if curl -fs --max-time 10 "https://$API/health" | grep -q '"ok":true'; then break; fi
  echo "waiting for the runner to come up..."
  sleep 10
done
curl -s "https://$API/health"; echo ""

echo ""
echo "Step: dashboard"
cd "$ROOT"
printf 'window.DQ_API="https://%s";\n' "$API" > doctrine-duel-qx-config-v1.js
DEP=$(vercel --prod --yes 2>&1 | grep -o 'https://[a-z0-9.-]*\.vercel\.app' | tail -1 || true)
SITE=$(vercel inspect "$DEP" 2>&1 | grep -o '[a-z0-9-]*\.vercel\.app' | awk '{print length, $0}' | sort -n | head -1 | cut -d' ' -f2 || true)
[ -n "$SITE" ] || SITE=${DEP#https://}

echo ""
echo "SAVE THIS dashboard login: $SITE/#k=$DASH"
echo "SAVE THIS dashboard key: $DASH"
echo "SAVE THIS runner api address: $API"
echo "SAVE THIS test bed join code: $JOIN"
