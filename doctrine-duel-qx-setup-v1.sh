#!/data/data/com.termux/files/usr/bin/bash
# doctrine-duel-qx setup v1. Safe to run again: it reuses everything that already exists.
set -e
ROOT="$HOME/doctrine-duel-qx"
TB="$HOME/2026-10-18-orange-testbed"
SERVICE="doctrine-duel-qx-api"
gen(){ node -e 'console.log(require("crypto").randomBytes(24).toString("hex"))'; }

echo ""
echo "Step: test bed server settings"
[ -d "$TB/.git" ] || git clone -q https://github.com/sudosilo/2026-10-18-orange-testbed "$TB"
cd "$TB"
[ -f .vercel/project.json ] || vercel link --yes --project 2026-10-18-orange-testbed >/dev/null 2>&1 || true
rm -f .env.dq
vercel env pull .env.dq --environment=production --yes >/dev/null 2>&1 || true
val(){ grep "^$1=" .env.dq 2>/dev/null | head -1 | cut -d= -f2- | sed 's/^"//;s/"$//'; }
JOIN=$(val JOIN_CODE); KS=$(val KEY_SECRET); GT=$(val GITHUB_TOKEN)
rm -f .env.dq
CHANGED=0
setv(){ vercel env rm "$1" production --yes >/dev/null 2>&1 || true; printf %s "$2" | vercel env add "$1" production >/dev/null 2>&1 || true; CHANGED=1; }
if [ -z "$JOIN" ]; then JOIN=$(gen); setv JOIN_CODE "$JOIN"; fi
if [ -z "$KS" ]; then setv KEY_SECRET "$(gen)"; fi
if [ -z "$GT" ]; then setv GITHUB_TOKEN "$(gh auth token)"; fi
if [ "$CHANGED" = 1 ]; then echo "Redeploying the test bed with its settings"; vercel --prod --yes >/dev/null 2>&1 || true; fi

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
railway status >/dev/null 2>&1 || railway init --name doctrine-duel-qx
railway service list --json 2>/dev/null | grep -q '"Redis"' || railway add --database redis
railway service list --json 2>/dev/null | grep -q "\"$SERVICE\"" || railway add --service "$SERVICE"
DASH=$(railway variables --service "$SERVICE" --kv 2>/dev/null | grep '^DASH_KEY=' | cut -d= -f2- || true)
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
