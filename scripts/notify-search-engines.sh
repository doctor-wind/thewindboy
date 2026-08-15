#!/usr/bin/env bash
# notify-search-engines.sh
# Automatically notify search engines about new/updated URLs after deployment.
#
# Usage: ./scripts/notify-search-engines.sh <site-url> [google-credentials-json-path]
#
# Features:
#   1. Compares current sitemap with previous build to find changed URLs
#   2. Submits changed URLs to IndexNow (Bing, Yandex, DuckDuckGo, etc.)
#   3. Optionally submits to Google Indexing API (if credentials provided)
#   4. Pings Google & Bing sitemap endpoints as fallback

set -euo pipefail

SITE_URL="${1:?Usage: $0 <site-url> [google-credentials-json]}"
GOOGLE_CREDS="${2:-}"
INDEXNOW_KEY="dd9d3eb16ccab79ed70e8508bcc5e0e0"
SITEMAP_URL="${SITE_URL}/sitemap.xml"
SITEMAP_CACHE=".sitemap-previous.xml"

echo "🔍 Fetching current sitemap..."
CURRENT_SITEMAP=$(curl -sL "$SITEMAP_URL" || echo "")

if [ -z "$CURRENT_SITEMAP" ]; then
  echo "⚠️  Could not fetch sitemap from $SITEMAP_URL"
  exit 0
fi

# Extract all URLs from sitemap
CURRENT_URLS=$(echo "$CURRENT_SITEMAP" | grep -oP '(?<=<loc>)[^<]+' | sort)

# Find new/changed URLs by comparing with previous sitemap
CHANGED_URLS=""
if [ -f "$SITEMAP_CACHE" ]; then
  PREVIOUS_URLS=$(grep -oP '(?<=<loc>)[^<]+' "$SITEMAP_CACHE" | sort)
  CHANGED_URLS=$(comm -23 <(echo "$CURRENT_URLS") <(echo "$PREVIOUS_URLS"))
else
  echo "📋 No previous sitemap cache found. Submitting all URLs."
  CHANGED_URLS="$CURRENT_URLS"
fi

# Save current sitemap for next comparison
echo "$CURRENT_SITEMAP" > "$SITEMAP_CACHE"

URL_COUNT=$(echo "$CHANGED_URLS" | grep -c '.' || echo "0")

if [ "$URL_COUNT" -eq 0 ]; then
  echo "✅ No new or changed URLs found. Skipping notifications."
else
  echo "📝 Found $URL_COUNT new/changed URL(s):"
  echo "$CHANGED_URLS" | head -20
  [ "$URL_COUNT" -gt 20 ] && echo "  ... and $((URL_COUNT - 20)) more"

  # ── IndexNow (Bing, Yandex, DuckDuckGo, etc.) ─────────────────────
  echo ""
  echo "📡 Submitting to IndexNow..."

  # Build JSON URL array
  URL_LIST_JSON=$(echo "$CHANGED_URLS" | head -100 | jq -R -s 'split("\n") | map(select(length > 0))')

  INDEXNOW_PAYLOAD=$(jq -n \
    --arg host "$(echo "$SITE_URL" | sed 's|https\?://||; s|/.*||')" \
    --arg key "$INDEXNOW_KEY" \
    --arg keyLocation "${SITE_URL}/${INDEXNOW_KEY}.txt" \
    --argjson urlList "$URL_LIST_JSON" \
    '{host: $host, key: $key, keyLocation: $keyLocation, urlList: $urlList}')

  INDEXNOW_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://api.indexnow.org/IndexNow" \
    -H "Content-Type: application/json" \
    -d "$INDEXNOW_PAYLOAD" || echo "000")

  if [ "$INDEXNOW_RESPONSE" = "200" ] || [ "$INDEXNOW_RESPONSE" = "202" ]; then
    echo "  ✅ IndexNow: Accepted ($INDEXNOW_RESPONSE)"
  else
    echo "  ⚠️  IndexNow: Response code $INDEXNOW_RESPONSE"
  fi

  # ── Google Indexing API (optional) ──────────────────────────────────
  if [ -n "$GOOGLE_CREDS" ] && [ -f "$GOOGLE_CREDS" ]; then
    echo ""
    echo "📡 Submitting to Google Indexing API..."

    # Get access token from service account
    ACCESS_TOKEN=$(python3 -c "
import json, time, jwt, urllib.request

with open('$GOOGLE_CREDS') as f:
    creds = json.load(f)

now = int(time.time())
payload = {
    'iss': creds['client_email'],
    'scope': 'https://www.googleapis.com/auth/indexing',
    'aud': 'https://oauth2.googleapis.com/token',
    'iat': now,
    'exp': now + 3600,
}
signed = jwt.encode(payload, creds['private_key'], algorithm='RS256')
data = urllib.parse.urlencode({
    'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    'assertion': signed
}).encode()
req = urllib.request.Request('https://oauth2.googleapis.com/token', data=data)
resp = json.loads(urllib.request.urlopen(req).read())
print(resp['access_token'])
" 2>/dev/null || echo "")

    if [ -n "$ACCESS_TOKEN" ]; then
      GOOGLE_OK=0
      GOOGLE_FAIL=0

      while IFS= read -r url; do
        [ -z "$url" ] && continue
        G_RESP=$(curl -s -o /dev/null -w "%{http_code}" \
          -X POST "https://indexing.googleapis.com/v3/urlNotifications:publish" \
          -H "Authorization: Bearer $ACCESS_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"url\": \"$url\", \"type\": \"URL_UPDATED\"}" || echo "000")

        if [ "$G_RESP" = "200" ]; then
          GOOGLE_OK=$((GOOGLE_OK + 1))
        else
          GOOGLE_FAIL=$((GOOGLE_FAIL + 1))
        fi
      done <<< "$(echo "$CHANGED_URLS" | head -200)"

      echo "  ✅ Google Indexing API: $GOOGLE_OK succeeded, $GOOGLE_FAIL failed"
    else
      echo "  ⚠️  Could not obtain Google access token. Skipping."
    fi
  else
    echo ""
    echo "ℹ️  Google Indexing API: No credentials provided. Skipping."
    echo "   To enable, set up a GCP service account and pass the JSON key path."
  fi
fi

# ── Sitemap ping (always) ─────────────────────────────────────────────
echo ""
echo "📡 Pinging sitemap endpoints..."

# Google
G_PING=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://www.google.com/ping?sitemap=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SITEMAP_URL', safe=''))")" || echo "000")
echo "  Google sitemap ping: $G_PING"

# Bing
B_PING=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://www.bing.com/ping?sitemap=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SITEMAP_URL', safe=''))")" || echo "000")
echo "  Bing sitemap ping: $B_PING"

echo ""
echo "🎉 Search engine notification complete!"
