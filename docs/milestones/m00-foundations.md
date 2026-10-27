# Milestone 0 — Foundations: Docker, Compose, Make, preflight checks

**What you'll have at the end:** one small web app running in Docker that you start with
`make up`, stop with `make down`, wipe with `make reset`, and a script (`make doctor`)
that tells anyone whether their Mac is ready for the lab.

**Time:** about 1–2 hours.

**How to use this guide:** do the steps in order. Every step tells you exactly which
file to open, what to type, and what you should see. Type the code yourself rather than
pasting — that's how it sticks. Each step ends with **Check**: if you don't see that
result, stop and fix it (or ask Claude) before moving on.

---

## Before you start: 6 words you'll use all the time

| Word | Meaning | Databricks equivalent |
|---|---|---|
| **Image** | A frozen template of software (e.g. Python 3.12 on Linux). | A Databricks Runtime version |
| **Container** | A running copy of an image. Throw it away and start a new one any time. | A cluster node |
| **Port mapping** | `8090:8000` = "port 8090 on my Mac goes to port 8000 inside the container". | The cluster's web UI address |
| **Bind mount** | A folder on your Mac that appears inside the container. | Workspace files |
| **Volume** | Storage Docker keeps even after the container is deleted. | DBFS / cloud storage |
| **Compose** | A YAML file that describes containers so one command starts them all. | Cluster configuration |

---

## Step 1 — Install Docker (Colima)

Docker needs a small Linux virtual machine on a Mac. We use **Colima** because it's free
and installs the same way on every Mac.

**1.1** In Terminal, install Colima, the Docker command and Docker Compose:

```bash
brew install colima docker docker-compose
```

**1.2** Tell Docker where Homebrew put Compose. (If `~/.docker/config.json` already
exists, open it and add the `cliPluginsExtraDirs` line by hand instead.)

```bash
mkdir -p ~/.docker && echo '{ "cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"] }' > ~/.docker/config.json
```

**1.3** Start the Linux VM with 4 CPUs, 8 GB memory and 60 GB disk:

```bash
colima start --cpu 4 --memory 8 --disk 60 --vm-type vz --vz-rosetta
```

**Check:** run this — you should see a "Hello from Docker!" message.

```bash
docker run --rm hello-world
```

> After restarting your Mac, run `colima start` again (it remembers the settings).

---

## Step 2 — Try Docker by hand (no files yet)

Run each command and look at what it prints. You'll write about it in your journal.

**2.1** Run Python inside a container, print the CPU type, and exit:

```bash
docker run --rm python:3.12-slim python -c "import platform; print(platform.machine())"
```

**Check:** it prints `aarch64` (Apple Silicon) or `x86_64` (Intel).

**2.2** Start a web server in the background (`-d`), named `web`, with Mac port 8099
going to container port 8000:

```bash
docker run -d --name web -p 8099:8000 python:3.12-slim python -m http.server 8000
```

**Check:** open http://localhost:8099 in your browser — you see a file listing.

**2.3** Look at it:

```bash
docker ps
```

```bash
docker logs web
```

**Check:** `docker ps` shows `web` with `0.0.0.0:8099->8000/tcp`. `docker logs` shows
your browser's request.

**2.4** Go inside the container:

```bash
docker exec -it web bash
```

Type `hostname`, then `ls /`, then `exit`.

**2.5** Delete it:

```bash
docker rm -f web
```

**Check:** `docker ps` no longer lists `web`.

---

## Step 3 — Create your `.env` file

`.env` holds your personal settings. `.env.example` is the template that goes into git.

**3.1** Make your copy:

```bash
cp .env.example .env
```

**3.2** Open `.env`. Find the last line `HELLO_PORT=` and change it to:

```
HELLO_PORT=8090
```

Save. Don't change anything else, and don't add quotes around values.

**Check:**

```bash
grep HELLO_PORT .env
```

prints `HELLO_PORT=8090`.

---

## Step 4 — Write `docker-compose.yml`

Open `docker-compose.yml`. It has 7 TODO blocks. For each one below, **delete the TODO
comment lines** and type the code shown in their place. Indentation matters in YAML:
use **spaces, never tabs**. Service settings are indented **4 spaces**.

**TODO 1 — image.** Replace `image: TODO` with:

```yaml
    image: python:3.12-slim
```

Why: an exact tag means everyone gets the same Python. `latest` changes over time.

**TODO 2 — profile.** Type:

```yaml
    profiles: ["core"]
```

Why: the service only starts when `COMPOSE_PROFILES` in `.env` includes `core`. Later,
big services get their own profiles so small Macs can skip them.

**TODO 3 — port.** Type:

```yaml
    ports:
      - "127.0.0.1:${HELLO_PORT:?set HELLO_PORT in .env}:8000"
```

Why: reads `HELLO_PORT` (8090) from `.env` and sends it to port 8000 inside the
container. `127.0.0.1:` means only your Mac can reach it, not other devices on your
Wi-Fi. `:?` makes Compose stop with that message if `HELLO_PORT` is missing.

**TODO 4 — volumes.** Type:

```yaml
    volumes:
      - ./docker/hello:/app:ro
      - hello-data:/data
```

Why: line 1 is a **bind mount** — the `docker/hello` folder on your Mac appears at
`/app` in the container, read-only (`ro`). That's how the container finds `app.py`.
Line 2 is a **named volume** — Docker-managed storage at `/data`, where the visit
counter is saved so it survives restarts.

**TODO 5 — environment.** Type:

```yaml
    environment:
      LAB_NAME: ${LAB_NAME}
```

Why: copies `LAB_NAME` from `.env` into the container, where `app.py` reads it.

**TODO 6 — healthcheck.** Type:

```yaml
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
      interval: 5s
      timeout: 3s
      retries: 5
```

Why: every 5 seconds Docker runs this inside the container. If the page answers, the
container is "healthy". It uses `localhost:8000` because the command runs *inside* the
container, where the app listens on 8000 — port 8090 only exists on your Mac.

**TODO 7 — declare the volume.** At the very bottom of the file, with **no indentation**,
type:

```yaml
volumes:
  hello-data:
```

Why: named volumes must be listed once at the top level of the file.

**Your finished file** (comments aside) must look exactly like this:

```yaml
services:
  hello:
    image: python:3.12-slim
    command: ["python", "/app/app.py"]
    profiles: ["core"]
    ports:
      - "127.0.0.1:${HELLO_PORT:?set HELLO_PORT in .env}:8000"
    volumes:
      - ./docker/hello:/app:ro
      - hello-data:/data
    environment:
      LAB_NAME: ${LAB_NAME}
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
      interval: 5s
      timeout: 3s
      retries: 5
    restart: unless-stopped

volumes:
  hello-data:
```

**Check 4a** — validate the file (this starts nothing):

```bash
docker compose config
```

You see the file printed back with `8090` and `Iceberg Lakehouse Lab` filled in. If you
see an error, it names the line — usually an indentation mistake.

**Check 4b** — start it by hand:

```bash
docker compose up -d --wait
```

```bash
curl localhost:8090
```

You see `Hello from Iceberg Lakehouse Lab!` and `visits: 1`. Run `curl` again:
`visits: 2`. Then stop it:

```bash
docker compose down
```

---

## Step 5 — Write `scripts/doctor.sh`

Open `scripts/doctor.sh`. Scroll to `# ---- checks`. There are 8 functions (A–H) that
each contain a comment and a `todo "..."` line. For each one: **delete the comments and
the `todo` line inside the function** and type the body shown. Keep the first and last
lines (`check_xxx() {` and `}`).

Reminder of the helpers you're calling (already written at the top of the file):
`ok "msg"` = green ✔, `warn "msg"` = yellow !, `fail "msg" "how to fix"` = red ✘,
`have cmd` = true if a command is installed.

**A — `check_chip`.** Shows Apple Silicon or Intel (information only):

```bash
check_chip() {
  case "$(uname -m)" in
    arm64)  ok "Apple Silicon (arm64)" ;;
    x86_64) ok "Intel (x86_64)" ;;
    *)      ok "CPU type: $(uname -m)" ;;
  esac
}
```

**B — `check_tools`.** git and make must be installed:

```bash
check_tools() {
  for tool in git make; do
    if have "$tool"; then
      ok "$tool is installed"
    else
      fail "$tool is missing" "xcode-select --install"
    fi
  done
}
```

**C — `check_docker_cli`.** The `docker` command must exist:

```bash
check_docker_cli() {
  if have docker; then
    ok "docker CLI $(docker version --format '{{.Client.Version}}' 2>/dev/null)"
  else
    fail "docker CLI not found" "follow Step 1 in docs/milestones/m00-foundations.md"
  fi
}
```

**D — `check_docker_running`.** The Docker VM must be on. `docker info` only succeeds
when it is. `have docker || return` skips this check if C already failed:

```bash
check_docker_running() {
  have docker || return
  if docker info >/dev/null 2>&1; then
    ok "Docker is running (runtime: $(docker context show))"
  else
    fail "Docker is not running" "colima start   (or open OrbStack / Docker Desktop)"
  fi
}
```

**E — `check_compose`.** `docker compose` (with a space) must work:

```bash
check_compose() {
  have docker || return
  local version
  if version=$(docker compose version --short 2>/dev/null); then
    ok "docker compose $version"
  else
    fail "docker compose does not work" "redo the ~/.docker/config.json line in Step 1"
  fi
}
```

**F — `check_docker_resources`.** How much memory and CPU the Docker VM has. Too little
memory is a warning, not a failure, because Milestone 0 is small:

```bash
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
```

**G — `check_disk`.** At least 15 GB free. `df -k .` reports free space in KB; `awk`
picks the 4th column of the 2nd line:

```bash
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
```

**H — `check_ports`.** Port 8090 must be free — unless our own lab is the one using it.
`lsof` lists which program is listening on a port:

```bash
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
```

**Check:**

```bash
bash scripts/doctor.sh
```

You see something like this, ending in **Ready**:

```
System
  ✔ macOS 27.2
  ✔ Apple Silicon (arm64)
  ✔ git is installed
  ✔ make is installed
  ✔ 109 GB free disk space

Docker
  ✔ docker CLI 29.9.2
  ✔ Docker is running (runtime: colima)
  ✔ docker compose 5.6.1
  ✔ Docker has 7 GB memory and 4 CPUs

Network
  ✔ port 8090 is free

Ready. 0 warning(s).
```

(8 GB shows as 7 GB because the VM keeps a little for itself — that's fine.)

---

## Step 6 — Write the `Makefile`

Open `Makefile`. Scroll to the TODO section. Each target has an `@echo "TODO..." && exit 1`
line (and some have `@# Hint` lines). For each target: **delete those lines** and type
the lines shown under the target name.

> **The one rule of Makefiles:** every command line under a target **starts with a Tab**,
> not spaces. In VS Code, the status bar should say "Tab Size" (not "Spaces") when a
> Makefile is open. If you see `missing separator`, a Tab became spaces.

`$(COMPOSE)` is a shortcut defined at the top of the Makefile for `docker compose`.

**doctor:**

```make
doctor: ## Check this Mac is ready for the lab
	@bash scripts/doctor.sh
```

**up** — `--wait` waits until the healthcheck says healthy:

```make
up: env ## Start the lab services in the background
	$(COMPOSE) up -d --wait
	@echo "Lab is up. Hello app: http://localhost:$(HELLO_PORT)"
```

**down** — no `-v`, so volumes (your data) are kept:

```make
down: ## Stop the lab (keeps data in volumes)
	$(COMPOSE) down
```

**ps:**

```make
ps: ## Show running services and their health
	$(COMPOSE) ps
```

**logs** — `-f` keeps following new lines until you press Ctrl-C:

```make
logs: ## Follow service logs (Ctrl-C to stop)
	$(COMPOSE) logs -f
```

**reset** — asks before deleting, unless you run `make reset FORCE=1`. The `\` at the end
of a line continues the same shell command on the next line. `$$ans` is written with two
`$` because Make uses `$` itself; Make turns `$$` into one `$` before the shell runs it:

```make
reset: ## Stop the lab AND delete all its data (asks first)
	@if [ "$(FORCE)" != "1" ]; then \
	  read -p "Delete all lab data? [y/N] " ans && [ "$$ans" = "y" ] || { echo "Cancelled."; exit 1; }; \
	fi
	$(COMPOSE) down -v
```

Leave `check-m00` as it is.

**Check** — try every target:

```bash
make up
```

ends with `Lab is up. Hello app: http://localhost:8090`.

```bash
make ps
```

shows `lakehouse-hello-1` with status `Up ... (healthy)`.

```bash
make logs
```

shows the app's log; press **Ctrl-C** to get your prompt back.

```bash
make down
```

removes the container.

```bash
make reset
```

asks `Delete all lab data? [y/N]` — type `n` and you see `Cancelled.`

---

## Step 7 — Run the checker

```bash
make check-m00
```

**Check:** sections 1–5 are all green ✔. Section 6 shows a red ✘ saying the journal
still has TODOs — that's expected; it passes after Step 9.

---

## Step 8 — Break it on purpose

Do these **5 experiments**. For each, write in the journal table: what you did, what
happened, why. Run `make up` before each one unless it says otherwise.

| # | Do this | Look for |
|---|---|---|
| 1 | `make down`, then start Step 2.2's container but with `-p 8090:8000`. Run `make doctor`, then `make up`. Finish with `docker rm -f web`. | doctor's red ✘ and the error `make up` gives |
| 2 | `curl localhost:8090` three times. `make down`. `make up`. `curl` again. Then `make reset` (type `y`), `make up`, `curl` again. | Does `visits` continue or restart at 1 after each? |
| 3 | In the Makefile, replace the Tab before `$(COMPOSE) ps` with 4 spaces. Run `make ps`. Put the Tab back. | the exact error message |
| 4 | In `.env`, put `#` in front of `HELLO_PORT=8090`. Run `docker compose config`. Remove the `#`. | the message from `:?` in TODO 3 |
| 5 | Run the command below, then change `8090` to `8000` and run it again. | which one works, and why |

Command for experiment 5:

```bash
docker compose exec hello python -c "import urllib.request as u; print(u.urlopen('http://localhost:8090/health').read())"
```

---

## Step 9 — Fill in the journal

Open `docs/journal/m00-foundations.md`. Replace every `TODO` with a short answer in your
own words (one or two sentences is enough). The answers are all in Steps 2–8.

**Check:** `make check-m00` now passes all 23 checks.

---

## Step 10 — Review and save

1. Ask Claude: **"review my Milestone 0 changes"**.
2. Then save your work in git:

```bash
git add -A
```

```bash
git commit -m "Complete Milestone 0"
```

```bash
git tag m00-foundations
```

---

## Troubleshooting

| You see | Cause | Fix |
|---|---|---|
| `Cannot connect to the Docker daemon` | Colima isn't running | `colima start` |
| `docker: 'compose' is not a docker command` | Step 1.2 missing | redo Step 1.2 |
| `can't open file '/app/app.py'` | The repo is outside your home folder; Colima only shares your home folder with Docker | keep the repo under `/Users/<you>/` (e.g. Desktop or Documents) |
| `port is already allocated` | Something else uses 8090 | `make doctor` shows what; stop it or change `HELLO_PORT` |
| `Makefile: *** missing separator` | Spaces instead of a Tab | retype the start of that line with the Tab key |
| `container ... is unhealthy` | The app crashed or the healthcheck is wrong | `make logs` to see why |
| YAML error naming a line | Indentation | 4 spaces before service settings, no tabs |
