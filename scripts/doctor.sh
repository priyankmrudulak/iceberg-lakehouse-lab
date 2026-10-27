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
# Read it line by line instead of `source .env`: values with spaces
# (LAB_NAME=Iceberg Lakehouse Lab) are fine for Docker but break `source`.
load_env() {
  [ -f .env ] || return 0
  local key value
  while IFS='=' read -r key value || [ -n "$key" ]; do
    case "$key" in ''|\#*) continue ;; esac
    value="${value%\"}"; value="${value#\"}"   # drop optional surrounding quotes
    export "$key=$value"
  done < .env
}
load_env

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
# Each check calls ok / warn / fail. Checks that need Docker start with
# `have docker || return` (or `docker info ... || return`) so they skip quietly
# when an earlier check has already reported the real problem.

# Must be macOS: `uname -s` prints "Darwin" on a Mac.
check_macos() {
  if [ "$(uname -s)" = "Darwin" ]; then
    ok "macOS $(sw_vers -productVersion)"
  else
    fail "this lab is written for macOS (found $(uname -s))"
  fi
}

# Information only: `uname -m` prints arm64 (Apple Silicon) or x86_64 (Intel).
check_chip() {
  case "$(uname -m)" in
    arm64)  ok "Apple Silicon (arm64)" ;;
    x86_64) ok "Intel (x86_64)" ;;
    *)      ok "CPU type: $(uname -m)" ;;
  esac
}

# git and make come with Apple's Command Line Tools.
check_tools() {
  for tool in git make; do
    if have "$tool"; then
      ok "$tool is installed"
    else
      fail "$tool is missing" "xcode-select --install"
    fi
  done
}

# The docker command itself (installed by `brew install docker`).
check_docker_cli() {
  if have docker; then
    ok "docker CLI $(docker version --format '{{.Client.Version}}' 2>/dev/null)"
  else
    fail "docker CLI not found" "follow Step 1 in docs/milestones/m00-foundations.md"
  fi
}

# The Docker VM must be on: `docker info` only succeeds when it is.
# `docker context show` names the runtime (colima, orbstack, desktop-linux).
check_docker_running() {
  have docker || return
  if docker info >/dev/null 2>&1; then
    ok "Docker is running (runtime: $(docker context show))"
  else
    fail "Docker is not running" "colima start   (or open OrbStack / Docker Desktop)"
  fi
}

# Compose v2 is a docker plugin, used as `docker compose` (with a space).
check_compose() {
  have docker || return
  local version
  if version=$(docker compose version --short 2>/dev/null); then
    ok "docker compose $version"
  else
    fail "docker compose does not work" "redo the ~/.docker/config.json line in Step 1"
  fi
}

# Memory/CPUs of the Docker VM (not the whole Mac). Bash only does whole-number
# maths, so 8 GB shows as 7 (the VM keeps a little for itself).
check_docker_resources() {
  docker info >/dev/null 2>&1 || return
  local mem_bytes mem_gb cpus
  mem_bytes=$(docker info --format '{{.MemTotal}}')
  mem_gb=$(( mem_bytes / 1024 / 1024 / 1024 ))
  cpus=$(docker info --format '{{.NCPU}}')
  if [ "$mem_gb" -ge "$MIN_DOCKER_MEM_GB" ]; then
    ok "Docker has ${mem_gb} GB memory and ${cpus} CPUs"
  else
    warn "Docker has only ${mem_gb} GB memory; later milestones need ${MIN_DOCKER_MEM_GB}+ (colima start --memory 8)"
  fi
}

# Free disk space here. `df -k .` reports KB; column 4 of line 2 is "Available".
check_disk() {
  local free_kb free_gb
  free_kb=$(df -k . | awk 'NR==2 {print $4}')
  free_gb=$(( free_kb / 1024 / 1024 ))
  if [ "$free_gb" -ge "$MIN_DISK_FREE_GB" ]; then
    ok "${free_gb} GB free disk space"
  else
    fail "only ${free_gb} GB free disk space (need ${MIN_DISK_FREE_GB})" "delete files or run: docker system prune"
  fi
}

# HELLO_PORT must be free, unless our own lab is the program using it.
# `lsof ... -sTCP:LISTEN` lists the program listening on a port.
check_ports() {
  if [ -z "${HELLO_PORT:-}" ]; then
    fail "HELLO_PORT is not set" "cp .env.example .env, then set HELLO_PORT=8090 in .env"
    return
  fi
  if docker compose ps --status running -q hello 2>/dev/null | grep -q .; then
    ok "port $HELLO_PORT is used by the lab itself (already running)"
    return
  fi
  local owner
  owner=$(lsof -nP -iTCP:"$HELLO_PORT" -sTCP:LISTEN 2>/dev/null | awk 'NR==2 {print $1}')
  if [ -n "$owner" ]; then
    fail "port $HELLO_PORT is already used by: $owner" "stop that program, or change HELLO_PORT in .env"
  else
    ok "port $HELLO_PORT is free"
  fi
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
