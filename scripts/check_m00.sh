#!/usr/bin/env bash
# check_m00.sh — automated check for Milestone 0. Run with: make check-m00
#
# You don't need to edit this file, but reading it is good practice:
# it shows how to test a Docker setup from a script.
#
# WARNING: the last step runs `make reset FORCE=1`, which deletes the lab's
# volumes. In Milestone 0 that's only the hello visit counter.

set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAILS=0
if [ -t 1 ]; then G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; N=$'\e[0m'; else G=; R=; Y=; N=; fi
pass() { printf "  ${G}✔${N} %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  ${R}✘${N} %s\n" "$1"; [ $# -ge 2 ] && printf "      hint: %s\n" "$2"; FAILS=$((FAILS + 1)); }
note() { printf "  ${Y}!${N} %s\n" "$1"; }
stop() { printf "\n${R}Stopped:${N} fix the item above first, then run make check-m00 again.\n"; exit 1; }
section() { printf "\n%s\n" "$1"; }

# Visit the hello page; prints the body (empty on failure).
hello() { curl -fsS --max-time 5 "http://localhost:${HELLO_PORT}/" 2>/dev/null; }
visits() { hello | awk '/^visits:/ {print $2}'; }

echo "Milestone 0 — check"

# --- 1. .env ------------------------------------------------------------------
section "1. Config (.env)"
if [ -f .env ]; then pass ".env exists"; else fail ".env is missing" "make env  (or: cp .env.example .env)"; stop; fi
set -a; . ./.env; set +a
if [ -n "${HELLO_PORT:-}" ]; then pass "HELLO_PORT=${HELLO_PORT}"; else fail "HELLO_PORT is empty in .env" "set it to a free port, e.g. 8088"; stop; fi
if git check-ignore -q .env; then pass ".env is git-ignored"; else fail ".env is NOT ignored by git" "add .env to .gitignore"; fi

# --- 2. preflight ----------------------------------------------------------------
section "2. Preflight (make doctor)"
# If our own stack is already up, doctor treats its port as fine.
DOC_OUT=$(mktemp)
if make -s doctor >"$DOC_OUT" 2>&1; then
  pass "make doctor passes"
else
  fail "make doctor did not pass — its output:"; sed 's/^/      /' "$DOC_OUT"
  rm -f "$DOC_OUT"; stop
fi
rm -f "$DOC_OUT"

# --- 3. compose file -----------------------------------------------------------
section "3. docker-compose.yml"
if ! CFG=$(docker compose config 2>&1); then
  fail "docker compose config failed:"; echo "$CFG" | sed 's/^/      /'; stop
fi
pass "file is valid"
has() { echo "$CFG" | grep -Eq "$1"; }
has '^ +image: python:[0-9]+\.[0-9]+[^ ]*slim' && ! has 'image: .*:latest' \
  && pass "image is pinned python slim ($(echo "$CFG" | awk '/^ +image:/ {print $2; exit}'))" \
  || fail "image should be an exact python slim tag" "TODO 1, e.g. python:3.12-slim"
has '^ +profiles:' && echo "$CFG" | grep -A3 '^ *profiles:' | grep -Eq -- '- core$' \
  && pass "service is in the core profile" || fail "service is not in the core profile" "TODO 2"
has 'target: 8000' && has "published: \"?${HELLO_PORT}\"?" \
  && pass "port ${HELLO_PORT} (Mac) -> 8000 (container)" || fail "port mapping missing or wrong" "TODO 3"
if has 'host_ip: 127\.0\.0\.1'; then pass "port bound to 127.0.0.1 only (bonus)"; else note "bonus: bind the port to 127.0.0.1 so other devices on your Wi-Fi can't reach it"; fi
echo "$CFG" | grep -B1 -A3 'target: /app' | grep -q 'read_only: true' \
  && pass "./docker/hello mounted read-only at /app" || fail "bind mount for /app missing or not read-only" "TODO 4a"
has 'source: hello-data' && has 'target: /data' \
  && pass "named volume hello-data at /data" || fail "named volume hello-data -> /data missing" "TODO 4b and TODO 7"
has '^ +LAB_NAME: ' && pass "LAB_NAME passed to the container" || fail "LAB_NAME not in environment" "TODO 5"
has '^ +healthcheck:' && pass "healthcheck defined" || fail "no healthcheck" "TODO 6"
[ $FAILS -eq 0 ] || stop

# --- 4. Makefile targets ---------------------------------------------------------
section "4. make up / ps / logs"
for t in up down ps logs reset; do
  if make -n "$t" 2>/dev/null | grep -q 'TODO'; then fail "make $t still has its TODO line"; fi
done
[ $FAILS -eq 0 ] || stop

if make -s up >/dev/null 2>&1; then pass "make up succeeded"; else fail "make up failed" "run it yourself to see the error"; stop; fi
CID=$(docker compose ps -q hello)
STATUS=$(docker inspect --format '{{.State.Health.Status}}' "$CID" 2>/dev/null)
[ "$STATUS" = healthy ] && pass "container is healthy right after make up" \
  || fail "container health is '$STATUS' after make up" "does make up use --wait? is the healthcheck right?"
BODY=$(hello)
echo "$BODY" | grep -q "Hello from ${LAB_NAME}" && pass "http://localhost:${HELLO_PORT} answers" \
  || fail "the hello page didn't answer as expected" "curl localhost:${HELLO_PORT}"
make -s ps >/dev/null 2>&1 && pass "make ps works" || fail "make ps failed"
make -n logs | grep -Eq 'logs.*(-f|--follow)' && pass "make logs follows the logs" \
  || fail "make logs should follow (-f)"

# --- 5. data survives a restart ------------------------------------------------
section "5. Volumes: down keeps data, reset deletes it"
V1=$(visits)
make -s down >/dev/null 2>&1 && pass "make down succeeded" || fail "make down failed"
[ -z "$(docker compose ps -q)" ] && pass "no containers left after make down" || fail "containers still running after make down"
make -s up >/dev/null 2>&1
V2=$(visits)
if [ -n "$V1" ] && [ -n "$V2" ] && [ "$V2" -gt "$V1" ]; then
  pass "visit counter survived down/up ($V1 -> $V2)"
else
  fail "counter did not survive down/up ($V1 -> $V2)" "make down must NOT use -v"
fi

VOL="${COMPOSE_PROJECT_NAME}_hello-data"
make -s reset FORCE=1 </dev/null >/dev/null 2>&1
if docker volume inspect "$VOL" >/dev/null 2>&1; then
  fail "volume $VOL still exists after make reset FORCE=1" "reset should use down -v; FORCE=1 should skip the question"
else
  pass "make reset FORCE=1 deleted the volume"
fi

# --- 6. journal ----------------------------------------------------------------
section "6. Journal"
J=docs/journal/m00-foundations.md
LEFT=$(grep -c 'TODO' "$J" 2>/dev/null || true)
[ "${LEFT:-0}" -eq 0 ] && pass "journal complete" || fail "journal still has $LEFT TODO(s)" "$J"

echo
if [ $FAILS -eq 0 ]; then
  printf "${G}Milestone 0 complete${N} (%d checks). Ask Claude for a review, then commit and tag m00-foundations.\n" "$PASS"
else
  printf "${R}%d check(s) failed${N}, %d passed.\n" "$FAILS" "$PASS"; exit 1
fi
