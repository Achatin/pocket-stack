#!/usr/bin/env bash
# ============================================================
# Micro-Stack Verification Script (Universal)
# Run after every change: ./verify.sh
# Exits 0 on success, 1 on any failure.
# ============================================================

set -euo pipefail

PB_URL="${PB_URL:-http://127.0.0.1:8090}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASS="${ADMIN_PASS:-password1234}"

PASS=0
FAIL=0

ok() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

# ── 1. Server Health ─────────────────────────────────────────
echo "=== 1. Server Health ==="
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$PB_URL/api/health")
if [ "$HEALTH" = "200" ]; then
  ok "Server running at $PB_URL"
else
  fail "Server not healthy (HTTP $HEALTH). Start with: ./pocketbase serve"
  exit 1
fi

# ── 2. Admin Auth ────────────────────────────────────────────
echo "=== 2. Admin Auth ==="
ADMIN_TOKEN=$(curl -s -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)

if [ -n "$ADMIN_TOKEN" ]; then
  ok "Admin authenticated (token len: ${#ADMIN_TOKEN})"
else
  fail "Admin auth failed. Check email/password or run: ./pocketbase superuser upsert EMAIL PASS"
  exit 1
fi

# ── 3. Extract collection info from index.html ───────────────
echo "=== 3. Parse index.html ==="
INDEX="pb_public/index.html"

if [ ! -f "$INDEX" ]; then
  fail "$INDEX not found"
  exit 1
fi

# Detect the first collection name used in pb.collection('...')
COLLECTION=$(grep -oP "pb\.collection\('\K[^']+" "$INDEX" | head -1)
if [ -z "$COLLECTION" ]; then
  fail "No pb.collection('...') call found in $INDEX"
  exit 1
fi
ok "Collection: $COLLECTION"

# Detect sort field from getList options
SORT=$(grep -oP "sort:\s*'?\K[^',}]+" "$INDEX" | head -1 || echo "-id")
SORT="${SORT:--id}"
ok "Sort: $SORT"

# ── 4. Schema Verification ───────────────────────────────────
echo "=== 4. Schema Verification ==="

# Fetch collection schema
SCHEMA_JSON=$(curl -s "$PB_URL/api/collections/$COLLECTION" \
  -H "Authorization: $ADMIN_TOKEN")

# Check collection exists
if ! echo "$SCHEMA_JSON" | python3 -c "import sys,json; json.load(sys.stdin)['fields']" >/dev/null 2>&1; then
  fail "Collection '$COLLECTION' not found or auth issue"
  exit 1
fi
ok "Collection '$COLLECTION' exists"

# Parse fields into arrays (skip system fields like id, created, updated)
# Output format: name|type|required|system
COL_FIELDS=$(echo "$SCHEMA_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for f in d.get('fields', []):
    print(f['name'], f['type'], f.get('required', False), f.get('system', False))
" 2>/dev/null)

# Separate user fields from system fields
USER_FIELDS=""
while IFS=' ' read -r name type required system; do
  [ "$system" = "True" ] && continue
  [ "$name" = "id" ] && continue
  USER_FIELDS="$USER_FIELDS $name"
  req_flag=""
  [ "$required" = "True" ] && req_flag=" (required)"
  echo "    - $name: $type$req_flag"
done <<< "$COL_FIELDS"

if [ -z "$USER_FIELDS" ]; then
  fail "No user-defined fields on '$COLLECTION'"
  exit 1
fi

# Verify sort field exists in schema
SORT_FIELD="${SORT#-}"  # strip leading -
SORT_FIELD="${SORT_FIELD#+}"  # strip leading +

if echo "$COL_FIELDS" | grep -q "^$SORT_FIELD "; then
  ok "Sort field '$SORT_FIELD' exists in schema"
else
  fail "Sort field '$SORT_FIELD' NOT in schema. Available fields:"
  echo "$COL_FIELDS" | while read -r name type _req _sys; do
    [ "$name" = "id" ] && continue
    echo "         - $name ($type)"
  done
  echo "  Fix: Change sort in $INDEX or add '$SORT_FIELD' field to collection"
fi

# ── 5. Build dynamic test payload from schema ────────────────
echo "=== 5. CRUD Smoke Test ==="

SMOKE_TAG="__smoke_$$__"

# Build CREATE payload from required user fields
# Maps PB field types to test values
CREATE_PAYLOAD=$(echo "$SCHEMA_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
fields = d.get('fields', [])
payload = {}
for f in fields:
    name = f['name']
    if f.get('system', False) or name == 'id':
        continue
    if not f.get('required', False):
        continue
    typ = f['type']
    opts = f.get('options', {})
    if typ == 'text':
        max_len = opts.get('max', 50)
        payload[name] = '__SMOKE__'[:max(max_len, 1)]
    elif typ == 'number':
        payload[name] = 1
    elif typ == 'bool':
        payload[name] = False
    elif typ == 'email':
        payload[name] = 'smoke@test.local'
    elif typ == 'url':
        payload[name] = 'https://example.com'
    elif typ == 'select':
        values = opts.get('values', ['smoke'])
        payload[name] = values[0]
    elif typ == 'json':
        payload[name] = {'smoke': True}
    elif typ == 'date':
        payload[name] = '2025-01-01 00:00:00'
    elif typ == 'file':
        continue  # skip file fields in smoke test
    elif typ == 'relation':
        continue  # skip relation fields (need valid record id)
    elif typ == 'editor':
        payload[name] = '<p>smoke</p>'
    else:
        payload[name] = 'smoke'
print(json.dumps(payload))
" 2>/dev/null)

if [ -z "$CREATE_PAYLOAD" ] || [ "$CREATE_PAYLOAD" = "{}" ]; then
  # No required user fields — use minimal payload
  CREATE_PAYLOAD='{}'
fi

# Substitute smoke tag
CREATE_PAYLOAD=$(echo "$CREATE_PAYLOAD" | sed "s/__SMOKE__/$SMOKE_TAG/g")
echo "  Test payload: $CREATE_PAYLOAD"

# ── 6. CREATE ────────────────────────────────────────────────
CREATE=$(curl -s -X POST "$PB_URL/api/collections/$COLLECTION/records" \
  -H "Content-Type: application/json" \
  -d "$CREATE_PAYLOAD")
SMOKE_ID=$(echo "$CREATE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

if [ -n "$SMOKE_ID" ]; then
  ok "CREATE: id=$SMOKE_ID"
else
  fail "CREATE failed: $(echo "$CREATE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message','unknown'))" 2>/dev/null)"
  exit 1
fi

# ── 7. READ ──────────────────────────────────────────────────
READ=$(curl -s "$PB_URL/api/collections/$COLLECTION/records/$SMOKE_ID")
READ_ID=$(echo "$READ" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ "$READ_ID" = "$SMOKE_ID" ]; then
  ok "READ: id matches"
else
  fail "READ: id mismatch"
fi

# ── 8. LIST (with same sort the app uses) ────────────────────
LIST_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "$PB_URL/api/collections/$COLLECTION/records?page=1&perPage=200&sort=$SORT")
if [ "$LIST_STATUS" = "200" ]; then
  LIST_COUNT=$(curl -s "$PB_URL/api/collections/$COLLECTION/records?page=1&perPage=200&sort=$SORT" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('items',[])))" 2>/dev/null)
  ok "LIST: HTTP 200 ($LIST_COUNT items with sort=$SORT)"
else
  fail "LIST: HTTP $LIST_STATUS (sort=$SORT)"
fi

# ── 9. UPDATE (toggle a bool field, or set text to updated) ──
UPDATE_PAYLOAD=""
BOOL_FIELD=""
TEXT_FIELD=""
while IFS=' ' read -r name type required system; do
  [ "$system" = "True" ] && continue
  [ "$name" = "id" ] && continue
  if [ "$type" = "bool" ] && [ -z "$BOOL_FIELD" ]; then
    BOOL_FIELD="$name"
  fi
  if [ "$type" = "text" ] && [ -z "$TEXT_FIELD" ]; then
    TEXT_FIELD="$name"
  fi
done <<< "$COL_FIELDS"

if [ -n "$BOOL_FIELD" ]; then
  # Read current value and flip it
  CURRENT_VAL=$(echo "$READ" | python3 -c "import sys,json; print(json.load(sys.stdin).get('$BOOL_FIELD', False))" 2>/dev/null)
  NEW_VAL="true"
  [ "$CURRENT_VAL" = "True" ] && NEW_VAL="false"
  UPDATE_PAYLOAD="{\"$BOOL_FIELD\": $NEW_VAL}"
elif [ -n "$TEXT_FIELD" ]; then
  UPDATE_PAYLOAD="{\"$TEXT_FIELD\": \"$SMOKE_TAG updated\"}"
fi

if [ -n "$UPDATE_PAYLOAD" ]; then
  UPDATE=$(curl -s -X PATCH "$PB_URL/api/collections/$COLLECTION/records/$SMOKE_ID" \
    -H "Content-Type: application/json" \
    -d "$UPDATE_PAYLOAD")
  UPDATE_ID=$(echo "$UPDATE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
  if [ -n "$UPDATE_ID" ]; then
    ok "UPDATE: $UPDATE_PAYLOAD"
  else
    fail "UPDATE failed: $(echo "$UPDATE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','unknown'))" 2>/dev/null)"
  fi
else
  ok "UPDATE: skipped (no bool or text field to update)"
fi

# ── 10. DELETE ───────────────────────────────────────────────
DEL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$PB_URL/api/collections/$COLLECTION/records/$SMOKE_ID")
if [ "$DEL_STATUS" = "204" ]; then
  ok "DELETE: HTTP 204"
else
  fail "DELETE: HTTP $DEL_STATUS"
fi

# ── 11. VERIFY DELETE ────────────────────────────────────────
VERIFY=$(curl -s "$PB_URL/api/collections/$COLLECTION/records/$SMOKE_ID" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))" 2>/dev/null)
if echo "$VERIFY" | grep -qi "not found\|wasn't found"; then
  ok "VERIFY DELETE: record gone"
else
  fail "VERIFY DELETE: record still exists"
fi

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

if [ "$FAIL" -gt 0 ]; then
  echo "FAILED — fix issues before shipping"
  exit 1
else
  echo "ALL PASSED — app is healthy"
  exit 0
fi
