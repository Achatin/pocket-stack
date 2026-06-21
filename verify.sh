#!/usr/bin/env bash
# ============================================================
# Micro-Stack Verification Script
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

# Check collection exists
COL_FIELDS=$(curl -s "$PB_URL/api/collections/$COLLECTION" \
  -H "Authorization: $ADMIN_TOKEN" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'fields' not in d:
    print('ERROR:' + str(d))
    sys.exit(1)
for f in d['fields']:
    print(f['name'], f['type'], f.get('required', False))
" 2>/dev/null)

if echo "$COL_FIELDS" | grep -q "^ERROR:"; then
  fail "Collection '$COLLECTION' not found or auth issue"
  exit 1
fi
ok "Collection '$COLLECTION' exists"

# Verify sort field exists in schema
SORT_FIELD="${SORT#-}"  # strip leading - for field name check
SORT_FIELD="${SORT_FIELD#+}"  # strip leading +

if echo "$COL_FIELDS" | grep -q "^$SORT_FIELD "; then
  ok "Sort field '$SORT_FIELD' exists in schema"
else
  fail "Sort field '$SORT_FIELD' NOT in schema. Available fields:"
  echo "$COL_FIELDS" | while read -r name type _req; do
    echo "         - $name ($type)"
  done
  echo "  Fix: Change sort in $INDEX or add '$SORT_FIELD' field to collection"
fi

# List all fields
echo "  Fields:"
echo "$COL_FIELDS" | while read -r name type req; do
  req_flag=""
  [ "$req" = "True" ] && req_flag=" (required)"
  echo "    - $name: $type$req_flag"
done

# ── 5. CRUD Smoke Test ───────────────────────────────────────
echo "=== 5. CRUD Smoke Test ==="

SMOKE_TEXT="__smoke_test_$$__"

# CREATE
CREATE=$(curl -s -X POST "$PB_URL/api/collections/$COLLECTION/records" \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"$SMOKE_TEXT\", \"done\": false}")
SMOKE_ID=$(echo "$CREATE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

if [ -n "$SMOKE_ID" ]; then
  ok "CREATE: id=$SMOKE_ID"
else
  fail "CREATE failed: $(echo $CREATE | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','unknown'))" 2>/dev/null)"
  exit 1
fi

# READ
READ=$(curl -s "$PB_URL/api/collections/$COLLECTION/records/$SMOKE_ID")
READ_TEXT=$(echo "$READ" | python3 -c "import sys,json; print(json.load(sys.stdin).get('text',''))" 2>/dev/null)
if [ "$READ_TEXT" = "$SMOKE_TEXT" ]; then
  ok "READ: text matches"
else
  fail "READ: text mismatch (got: '$READ_TEXT')"
fi

# LIST with same params the app uses
LIST_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "$PB_URL/api/collections/$COLLECTION/records?page=1&perPage=200&sort=$SORT")
if [ "$LIST_STATUS" = "200" ]; then
  LIST_COUNT=$(curl -s "$PB_URL/api/collections/$COLLECTION/records?page=1&perPage=200&sort=$SORT" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('items',[])))" 2>/dev/null)
  ok "LIST: HTTP 200 ($LIST_COUNT items with sort=$SORT)"
else
  fail "LIST: HTTP $LIST_STATUS (sort=$SORT)"
fi

# UPDATE
UPDATE=$(curl -s -X PATCH "$PB_URL/api/collections/$COLLECTION/records/$SMOKE_ID" \
  -H "Content-Type: application/json" \
  -d '{"done": true}')
UPDATE_DONE=$(echo "$UPDATE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('done',''))" 2>/dev/null)
if [ "$UPDATE_DONE" = "True" ] || [ "$UPDATE_DONE" = "true" ]; then
  ok "UPDATE: done=true"
else
  fail "UPDATE failed (done=$UPDATE_DONE)"
fi

# DELETE
DEL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$PB_URL/api/collections/$COLLECTION/records/$SMOKE_ID")
if [ "$DEL_STATUS" = "204" ]; then
  ok "DELETE: HTTP 204"
else
  fail "DELETE: HTTP $DEL_STATUS"
fi

# VERIFY DELETE
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
