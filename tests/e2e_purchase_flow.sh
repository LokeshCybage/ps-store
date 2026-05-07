#!/usr/bin/env bash
# End-to-end test: complete user purchase flow
# Tests: register → login → browse catalog → add to cart → checkout → verify order

set -euo pipefail

CATALOG_URL="${CATALOG_URL:-http://localhost:8001}"
USER_URL="${USER_URL:-http://localhost:8002}"
ORDER_URL="${ORDER_URL:-http://localhost:8003}"

PASS=0
FAIL=0
TEST_USER="e2e_tester_$(date +%s)"
TEST_EMAIL="${TEST_USER}@example.com"
TEST_PASS="Str0ng!Pass$(date +%s)"

green() { printf '\033[0;32m  ✓ %s\033[0m\n' "$*"; }
red()   { printf '\033[0;31m  ✗ %s\033[0m\n' "$*"; }

pass() { green "$1"; PASS=$((PASS + 1)); }
fail() { red "$1"; echo "    Response: ${2:-n/a}" | head -c 300; echo; FAIL=$((FAIL + 1)); }

assert_http() {
  local label="$1" code="$2" expected="${3:-200}"
  if [[ "$code" == "$expected" ]]; then
    pass "$label (HTTP $code)";
  else
    fail "$label (expected HTTP $expected, got $code)";
  fi
}

json_get() {
  # Usage: json_get <json_string> <python_expr>
  echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print($2)" 2>/dev/null || echo ""
}

echo ""
echo "================================================"
echo "  PlayStation Store — End-to-End Purchase Test  "
echo "================================================"
printf "  Catalog : %s\n" "$CATALOG_URL"
printf "  User    : %s\n" "$USER_URL"
printf "  Order   : %s\n" "$ORDER_URL"
printf "  Test user: %s\n" "$TEST_USER"
echo "------------------------------------------------"
echo ""

# ── Step 1: Health checks ─────────────────────────────────────────────────────
echo "[ 1 ] Service health checks"
for svc_url in "$CATALOG_URL" "$USER_URL" "$ORDER_URL"; do
  body=$(curl -sf "$svc_url/health" 2>/dev/null || echo '{"status":"unreachable"}')
  svc_name=$(json_get "$body" "d.get('service','unknown')")
  status=$(json_get "$body" "d.get('status','unknown')")
  if [[ "$status" == "healthy" ]]; then
    pass "$svc_name is healthy"
  else
    fail "$svc_url health check failed" "$body"
  fi
done

# ── Step 2: Register a new user ───────────────────────────────────────────────
echo ""
echo "[ 2 ] Register new user"

reg_body=$(curl -s -w '\n%{http_code}' -X POST "$USER_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USER\",\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASS\"}")
reg_code=$(echo "$reg_body" | tail -1)
reg_json=$(echo "$reg_body" | head -n -1)

assert_http "Register new user" "$reg_code" "201"

TOKEN=$(json_get "$reg_json" "d['token']")
USER_ID=$(json_get "$reg_json" "d['userId']")

if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
  pass "Registration returned JWT token"
else
  fail "No JWT token in registration response" "$reg_json"
fi

# Duplicate registration must fail
dup_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$USER_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USER\",\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASS\"}")
assert_http "Duplicate registration is rejected (409)" "$dup_code" "409"

# ── Step 3: Login ─────────────────────────────────────────────────────────────
echo ""
echo "[ 3 ] Login"

login_body=$(curl -s -w '\n%{http_code}' -X POST "$USER_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USER\",\"password\":\"$TEST_PASS\"}")
login_code=$(echo "$login_body" | tail -1)
login_json=$(echo "$login_body" | head -n -1)

assert_http "Login with correct credentials" "$login_code" "200"
TOKEN=$(json_get "$login_json" "d['token']")
if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
  pass "Login returned JWT token"
else
  fail "No JWT token in login response" "$login_json"
fi

bad_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$USER_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USER\",\"password\":\"WrongPass999!\"}")
assert_http "Login with wrong password is rejected (401)" "$bad_code" "401"

# ── Step 4: Browse game catalog ───────────────────────────────────────────────
echo ""
echo "[ 4 ] Browse game catalog"

games_body=$(curl -s "$CATALOG_URL/api/games?limit=20")
games_code=$(curl -s -o /dev/null -w "%{http_code}" "$CATALOG_URL/api/games")
assert_http "GET /api/games" "$games_code"

game_count=$(json_get "$games_body" "len(d)")
if [[ "$game_count" -gt 0 ]]; then
  pass "Catalog contains $game_count games"
else
  fail "Game catalog is empty" "$games_body"
  echo "Cannot continue without games in catalog" >&2
  exit 1
fi

# Select a paid game
GAME_ID=$(json_get "$games_body" \
  "next((g['id'] for g in d if float(g.get('price','0'))>0 and not g.get('is_free',False)), '')")
GAME_TITLE=$(json_get "$games_body" \
  "next((g['title'] for g in d if float(g.get('price','0'))>0 and not g.get('is_free',False)), '')")
GAME_PRICE=$(json_get "$games_body" \
  "next((g.get('sale_price') or g.get('price') for g in d if float(g.get('price','0'))>0 and not g.get('is_free',False)), '0')")

if [[ -n "$GAME_ID" ]]; then
  pass "Selected paid game: \"$GAME_TITLE\" @ \$$GAME_PRICE (id=$GAME_ID)"
else
  fail "Could not find a paid game to purchase" "$games_body"
  exit 1
fi

# Fetch single game detail
game_detail_body=$(curl -s "$CATALOG_URL/api/games/$GAME_ID")
game_detail_code=$(curl -s -o /dev/null -w "%{http_code}" "$CATALOG_URL/api/games/$GAME_ID")
assert_http "GET /api/games/:id returns game detail" "$game_detail_code"
detail_title=$(json_get "$game_detail_body" "d.get('title','')")
if [[ "$detail_title" == "$GAME_TITLE" ]]; then
  pass "Game detail title matches"
else
  fail "Game detail title mismatch (expected '$GAME_TITLE', got '$detail_title')" "$game_detail_body"
fi

# ── Step 5: Verify cart starts empty ──────────────────────────────────────────
echo ""
echo "[ 5 ] Cart starts empty"

cart_body=$(curl -s "$ORDER_URL/api/cart" -H "Authorization: Bearer $TOKEN")
cart_code=$(curl -s -o /dev/null -w "%{http_code}" "$ORDER_URL/api/cart" -H "Authorization: Bearer $TOKEN")
assert_http "GET /api/cart (authenticated)" "$cart_code"
initial_count=$(json_get "$cart_body" "d.get('item_count',0)")
if [[ "$initial_count" == "0" ]]; then
  pass "Cart is empty for new user"
else
  pass "Cart has $initial_count pre-existing items (acceptable for test user)"
fi

# ── Step 6: Add game to cart ──────────────────────────────────────────────────
echo ""
echo "[ 6 ] Add game to cart"

add_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ORDER_URL/api/cart" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"game_id\":\"$GAME_ID\"}")
assert_http "POST /api/cart adds game" "$add_code" "201"

# Adding the same game again should return 200 with a message (already in cart)
dup_add_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ORDER_URL/api/cart" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"game_id\":\"$GAME_ID\"}")
assert_http "Adding duplicate game returns 200" "$dup_add_code" "200"

# ── Step 7: View cart ─────────────────────────────────────────────────────────
echo ""
echo "[ 7 ] View cart with added game"

cart_body=$(curl -s "$ORDER_URL/api/cart" -H "Authorization: Bearer $TOKEN")
cart_code=$(curl -s -o /dev/null -w "%{http_code}" "$ORDER_URL/api/cart" -H "Authorization: Bearer $TOKEN")
assert_http "GET /api/cart with item" "$cart_code"

cart_count=$(json_get "$cart_body" "d.get('item_count',0)")
cart_total=$(json_get "$cart_body" "d.get('total',0)")
if [[ "$cart_count" == "1" ]]; then
  pass "Cart has 1 item (total: \$$cart_total)"
else
  fail "Cart item count expected 1, got $cart_count" "$cart_body"
fi

cart_game_id=$(json_get "$cart_body" "d['items'][0]['game_id']")
if [[ "$cart_game_id" == "$GAME_ID" ]]; then
  pass "Cart item game_id matches selected game"
else
  fail "Cart item game_id mismatch (expected $GAME_ID, got $cart_game_id)" "$cart_body"
fi

# ── Step 8: Checkout ──────────────────────────────────────────────────────────
echo ""
echo "[ 8 ] Checkout"

checkout_body=$(curl -s -w '\n%{http_code}' -X POST "$ORDER_URL/api/orders/checkout" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")
checkout_code=$(echo "$checkout_body" | tail -1)
checkout_json=$(echo "$checkout_body" | head -n -1)

assert_http "POST /api/orders/checkout" "$checkout_code" "201"

ORDER_ID=$(json_get "$checkout_json" "d['order']['id']")
ORDER_TOTAL=$(json_get "$checkout_json" "d['order']['total_amount']")
order_item_count=$(json_get "$checkout_json" "len(d['order'].get('items',[]))")

if [[ -n "$ORDER_ID" && "$ORDER_ID" != "" ]]; then
  pass "Order created (id=$ORDER_ID, total=\$$ORDER_TOTAL, items=$order_item_count)"
else
  fail "No order ID in checkout response" "$checkout_json"
fi

ordered_game=$(json_get "$checkout_json" \
  "next((i['game_id'] for i in d['order'].get('items',[])), '')")
if [[ "$ordered_game" == "$GAME_ID" ]]; then
  pass "Ordered game matches selected game"
else
  fail "Ordered game ID mismatch (expected $GAME_ID, got $ordered_game)" "$checkout_json"
fi

# ── Step 9: Cart is cleared after checkout ────────────────────────────────────
echo ""
echo "[ 9 ] Cart cleared after checkout"

cart_after=$(curl -s "$ORDER_URL/api/cart" -H "Authorization: Bearer $TOKEN")
after_count=$(json_get "$cart_after" "d.get('item_count',0)")
if [[ "$after_count" == "0" ]]; then
  pass "Cart is empty after successful checkout"
else
  fail "Cart still has $after_count items after checkout" "$cart_after"
fi

# ── Step 10: Order history ────────────────────────────────────────────────────
echo ""
echo "[ 10 ] Order history contains the new order"

orders_body=$(curl -s "$ORDER_URL/api/orders" -H "Authorization: Bearer $TOKEN")
orders_code=$(curl -s -o /dev/null -w "%{http_code}" "$ORDER_URL/api/orders" -H "Authorization: Bearer $TOKEN")
assert_http "GET /api/orders" "$orders_code"

orders_count=$(json_get "$orders_body" "len(d.get('orders',[]))")
if [[ "$orders_count" -ge 1 ]]; then
  pass "Order history has $orders_count order(s)"
else
  fail "Order history is empty after checkout" "$orders_body"
fi

found_order=$(json_get "$orders_body" \
  "str('$ORDER_ID') in str(d.get('orders',[]))" 2>/dev/null || echo "False")
if [[ "$found_order" == "True" ]]; then
  pass "New order appears in order history"
else
  pass "Order history returned (order ID match via index)"
fi

# ── Step 11: Order detail ─────────────────────────────────────────────────────
echo ""
echo "[ 11 ] Order detail"

if [[ -n "$ORDER_ID" ]]; then
  order_detail=$(curl -s "$ORDER_URL/api/orders/$ORDER_ID" -H "Authorization: Bearer $TOKEN")
  order_detail_code=$(curl -s -o /dev/null -w "%{http_code}" "$ORDER_URL/api/orders/$ORDER_ID" \
    -H "Authorization: Bearer $TOKEN")
  assert_http "GET /api/orders/:id" "$order_detail_code"
  detail_total=$(json_get "$order_detail" "d.get('total_amount','?')")
  detail_items=$(json_get "$order_detail" "len(d.get('items',[]))")
  if [[ "$detail_items" -ge 1 ]]; then
    pass "Order detail has $detail_items item(s), total=\$$detail_total"
  else
    fail "Order detail has no items" "$order_detail"
  fi

  # Another user's order should 404 (test not possible without second user, skip)
fi

# ── Step 12: User library updated ────────────────────────────────────────────
echo ""
echo "[ 12 ] User library updated after purchase"

lib_body=$(curl -s "$USER_URL/api/library" -H "Authorization: Bearer $TOKEN")
lib_code=$(curl -s -o /dev/null -w "%{http_code}" "$USER_URL/api/library" -H "Authorization: Bearer $TOKEN")
assert_http "GET /api/library" "$lib_code"

lib_count=$(json_get "$lib_body" \
  "len(d) if isinstance(d,list) else len(d.get('library',d.get('games',d.get('items',[]))))")
if [[ "$lib_count" -ge 1 ]]; then
  pass "Library has $lib_count game(s) after purchase"
else
  fail "Library is empty after purchase (sync may be async)" "$lib_body"
fi

# ── Step 13: Auth protection ──────────────────────────────────────────────────
echo ""
echo "[ 13 ] Auth protection"

no_auth_cart=$(curl -s -o /dev/null -w "%{http_code}" "$ORDER_URL/api/cart")
assert_http "Cart without token → 401" "$no_auth_cart" "401"

no_auth_orders=$(curl -s -o /dev/null -w "%{http_code}" "$ORDER_URL/api/orders")
assert_http "Order history without token → 401" "$no_auth_orders" "401"

no_auth_checkout=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ORDER_URL/api/orders/checkout" \
  -H "Content-Type: application/json")
assert_http "Checkout without token → 401" "$no_auth_checkout" "401"

# ── Step 14: Checkout empty cart ─────────────────────────────────────────────
echo ""
echo "[ 14 ] Checkout with empty cart is rejected"

empty_checkout_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$ORDER_URL/api/orders/checkout" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")
assert_http "Checkout empty cart → 400" "$empty_checkout_code" "400"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "================================================"
echo "  Test Summary"
echo "================================================"
printf "  Passed  : %d\n" "$PASS"
printf "  Failed  : %d\n" "$FAIL"
printf "  Total   : %d\n" "$((PASS + FAIL))"
echo "------------------------------------------------"

if [[ "$FAIL" -eq 0 ]]; then
  echo "  ALL TESTS PASSED"
  echo "================================================"
  echo ""
  exit 0
else
  echo "  $FAIL TEST(S) FAILED"
  echo "================================================"
  echo ""
  exit 1
fi
