#!/usr/bin/env bash
# doctor.sh — checks that this Mac is ready to run the lab.
#
# Run:   bash scripts/doctor.sh     (or: make doctor)
# Exit:  0 if everything required passes, 1 otherwise.
#
# How it works: each check_* function calls ok / warn / fail / todo.
#   ok    the requirement is met
#   warn  works, but not ideal (does NOT make the script fail)
#   fail  the lab won't work until this is fixed (script exits 1)
#   todo  you haven't written this check yet (counts as a failure)
#
# Note: macOS ships an old bash (3.2). Avoid bash-4 features like
# associative arrays or ${var,,}. Everything below works on 3.2.

set -uo pipefail   # no "-e": a failing check must not stop the other checks

# Run from the repo root no matter where the script is called from.
cd "$(dirname "$0")/.."

# ---- settings ---------------------------------------------------------------
MIN_DOCKER_MEM_GB=6     # Docker VM memory needed for the "core" profile
MIN_DISK_FREE_GB=15     # free disk space needed for images + data

# Load .env if it exists so we know which ports the lab wants.
if [ -f .env ]; then
  set -a; . ./.env; set +a
fi

# ---- helpers (already done) -------------------------------------------------
FAILS=0; WARNS=0; TODOS=0
if [ -t 1 ]; then G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[34m'; N=$'\e[0m'; else G=; Y=; R=; B=; N=; fi

ok()   { printf "  ${G}✔${N} %s\n" "$1"; }
warn() { printf "  ${Y}!${N} %s\n" "$1"; WARNS=$((WARNS + 1)); }
fail() { printf "  ${R}✘${N} %s\n" "$1"; [ $# -ge 2 ] && printf "      fix: %s\n" "$2"; FAILS=$((FAILS + 1)); }
todo() { printf "  ${B}…${N} TODO: %s\n" "$1"; TODOS=$((TODOS + 1)); }
section() { printf "\n%s\n" "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }   # usage: if have docker; then ...

# ---- checks -----------------------------------------------------------------

# EXAMPLE — this one is done. Copy its shape for the others.
check_macos() {
  if [ "$(uname -s)" = "Darwin" ]; then
    ok "macOS $(sw_vers -productVersion)"
  else
    fail "this lab is written for macOS (found $(uname -s))"
  fi
}

check_chip() {
  # TODO A — report the CPU type. This is information only, so use ok, never fail.
  #   `uname -m` prints arm64 (Apple Silicon) or x86_64 (Intel).
  #   Print e.g.  ok "Apple Silicon (arm64)"  or  ok "Intel (x86_64)".
  todo "report Apple Silicon vs Intel"
}

check_tools() {
  # TODO B — git and make must exist.
  #   Use the `have` helper. If missing, fail with the fix: xcode-select --install
  todo "check git and make are installed"
}

check_docker_cli() {
  # TODO C — the docker command must exist.
  #   Missing → fail with a fix that points to Task 0 of docs/milestones/m00-foundations.md
  todo "check the docker CLI is installed"
}

check_docker_running() {
  # TODO D — the Docker VM/daemon must be running.
  #   `docker info >/dev/null 2>&1` succeeds only when it is.
  #   Not running → fail with fix: "colima start" (or open OrbStack / Docker Desktop).
  #   Bonus: tell the user WHICH runtime is active.
  #     `docker context show` prints e.g. colima, orbstack, desktop-linux.
  todo "check the Docker daemon is running"
}

check_compose() {
  # TODO E — Docker Compose v2 must work as `docker compose` (with a space).
  #   `docker compose version --short` prints e.g. 2.39.1
  #   Fail if the command errors. Print the version on success.
  todo "check docker compose v2 works"
}

check_docker_resources() {
  # TODO F — memory and CPUs given to the Docker VM (not your whole Mac!).
  #   `docker info --format '{{.MemTotal}}'`  → bytes   (divide by 1024^3 for GB)
  #   `docker info --format '{{.NCPU}}'`      → CPU count
  #   Memory below MIN_DOCKER_MEM_GB → warn (later milestones need it, M0 doesn't).
  #   Hint: bash only does integer maths: $(( bytes / 1024 / 1024 / 1024 ))
  #   Skip this check (just return) if Docker isn't running — the earlier check already failed.
  todo "check Docker memory and CPUs"
}

check_disk() {
  # TODO G — free disk space in the repo's folder.
  #   `df -k .` prints a header line, then: Filesystem 1K-blocks Used Available ...
  #   Take the 4th column of the 2nd line: df -k . | awk 'NR==2 {print $4}'
  #   Convert KB → GB, fail if below MIN_DISK_FREE_GB.
  todo "check free disk space"
}

check_ports() {
  # TODO H — every port the lab uses must be free on the Mac.
  #   For now that is just HELLO_PORT (later: MinIO, Jupyter, Spark UI ...).
  #   If HELLO_PORT is empty → fail with fix: "copy .env.example to .env and set HELLO_PORT"
  #   `lsof -nP -iTCP:"$port" -sTCP:LISTEN` prints a line if something is listening.
  #   Careful: if the LAB ITSELF is already running on that port, that's fine.
  #     `docker compose ps --status running -q hello` prints an id if our container is up.
  #   Bonus: loop over a list of ports so later milestones only add to the list.
  todo "check the lab's ports are free"
}

# ---- run ----------------------------------------------------------------------
echo "Lakehouse lab — preflight checks"

section "System";  check_macos; check_chip; check_tools; check_disk
section "Docker";  check_docker_cli; check_docker_running; check_compose; check_docker_resources
section "Network"; check_ports

echo
if [ $((FAILS + TODOS)) -eq 0 ]; then
  printf "${G}Ready.${N} %d warning(s).\n" "$WARNS"
  exit 0
else
  printf "${R}Not ready:${N} %d failed, %d TODO, %d warning(s).\n" "$FAILS" "$TODOS" "$WARNS"
  exit 1
fi
