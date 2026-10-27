# Milestone 0 — Foundations: Docker, Compose, Make, preflight checks

**Goal:** by the end you can start, stop, inspect and reset a small multi-file Docker
setup with one command, and a script tells anyone whether their Mac is ready for the lab.

**Why this matters for Databricks:** Databricks hides the infrastructure. When you click
"create cluster", it picks a machine image (a Databricks Runtime), wires up storage, sets
config and networking for you. In this lab *you* do that job. Docker images play the
role of the Databricks Runtime, Compose plays the role of the cluster/workspace config,
and the Makefile is your "Run" button.

You will touch these files:

| File | You do |
|---|---|
| `.env.example` → `.env` | Pick a port |
| `docker-compose.yml` | Fill in the service definition (TODOs) |
| `scripts/doctor.sh` | Write the preflight checks (TODOs) |
| `Makefile` | Write the lab commands (TODOs) |
| `docs/journal/m00-foundations.md` | Answer the questions |

Already written for you (read them, don't need to change them):
`docker/hello/app.py` (a tiny web app) and `scripts/check_m00.sh` (the checker).

---

## 1. Concepts in 5 minutes

| Term | What it is | Databricks analogy |
|---|---|---|
| **Image** | A read-only template: OS + software + files. Built from a `Dockerfile` or pulled from a registry. | Databricks Runtime version (e.g. "15.4 LTS") |
| **Container** | A running instance of an image. Disposable — delete it and recreate it any time. | A running cluster node |
| **Tag** | A version label on an image: `python:3.12-slim`. `latest` is a moving target — never use it in a lab others must reproduce. | Pinning a runtime version |
| **Port mapping** | `host:container` — `8088:8000` means "localhost:8088 on my Mac reaches port 8000 inside the container". | Cluster driver UI / JDBC endpoint |
| **Bind mount** | A folder on your Mac appears inside the container (`./docker/hello:/app`). Edit on the Mac, the container sees it instantly. | Repos / workspace files |
| **Named volume** | Storage managed by Docker that survives container deletion. | DBFS / cloud storage |
| **Network** | Compose puts all services on one private network; they reach each other by **service name** (`http://minio:9000`), not `localhost`. | Cluster VPC |
| **Compose** | One YAML file describing many containers and how they connect. `docker compose up` starts them all. | Cluster + job config |
| **Profile** | A label on a service so it only starts when that profile is enabled. Lets small Macs run less. | Choosing cluster size/features |
| **Healthcheck** | A command Docker runs to decide if a container is actually *working*, not just running. | Cluster "Running" vs "Pending" |
| **Make** | Runs named commands (`make up`) from a `Makefile`. Gives every learner the same simple interface. | The "Run" button |

**Most common confusion:** inside a container, `localhost` means *that container*, not
your Mac and not other containers. From your Mac you use `localhost:<host port>`; between
containers you use `<service name>:<container port>`.

---

## 2. Tasks

### Task 0 — Install a Docker runtime

Docker needs a small Linux VM on macOS. Pick one (the lab works with all three):

| Option | Why pick it | Install |
|---|---|---|
| **Colima** (recommended) | Free, open source, scriptable — easiest for others to reproduce exactly | see below |
| OrbStack | Fastest, nicest UI; free for personal use | `brew install --cask orbstack`, then open it once |
| Docker Desktop | Most common; licence needed at larger companies | `brew install --cask docker`, then open it once |

Colima setup:

```bash
brew install colima docker docker-compose
```

Tell the Docker CLI where Homebrew put the Compose plugin (so `docker compose` works):

```bash
mkdir -p ~/.docker && echo '{ "cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"] }' > ~/.docker/config.json
```

Start the VM with enough resources for the later milestones (you have 16 GB RAM):

```bash
colima start --cpu 4 --memory 8 --disk 60 --vm-type vz --vz-rosetta
```

Verify:

```bash
docker run --rm hello-world
```

> If `~/.docker/config.json` already existed, merge the line in by hand instead of overwriting it.

### Task 1 — Warm up with plain Docker (no files yet)

Run each command, and write one line in your journal about what you saw.

```bash
docker run --rm -it python:3.12-slim python -c "import platform; print(platform.machine(), platform.python_version())"
```

```bash
docker run -d --name web -p 8099:8000 python:3.12-slim python -m http.server 8000
```

Open http://localhost:8099, then try:

```bash
docker ps
```

```bash
docker logs web
```

```bash
docker exec -it web bash
```

(Inside: `ls /`, `hostname`, `exit`.) Then clean up:

```bash
docker rm -f web
```

### Task 2 — Create your `.env`

```bash
cp .env.example .env
```

Fill in the TODO in `.env`. **Never commit `.env`** — it's already in `.gitignore`.
`.env.example` is the committed template others copy.

### Task 3 — Fill in `docker-compose.yml`

Follow the TODOs. Check your YAML without starting anything:

```bash
docker compose config
```

This prints the fully resolved file (with `.env` values substituted) or an error.
Then try it by hand before the Makefile exists:

```bash
docker compose up -d
```

```bash
curl localhost:8088
```

(Use the port you chose.) Refresh a few times — the visit counter goes up.

### Task 4 — Write `scripts/doctor.sh`

Follow the TODOs. One check is done for you as a pattern. Run it with:

```bash
bash scripts/doctor.sh
```

It must exit `0` when the Mac is ready and non-zero when it isn't.

### Task 5 — Write the `Makefile`

Follow the TODOs. `make help` already works — run it to see the targets.

> Make's #1 gotcha: recipe lines **must start with a Tab**, not spaces.

### Task 6 — Check your work

```bash
make check-m00
```

The checker runs doctor, starts the stack, checks the healthcheck, checks the counter
survives a restart (volume), checks `make reset` wipes it, and checks your journal.

---

## 3. Break it (do at least three, note what happened in your journal)

1. **Port clash.** Run Task 1's `web` container again but on *your* `HELLO_PORT`, then
   `make up`. What error do you get? Does `make doctor` catch it beforehand?
2. **Volume vs container.** `make up`, visit a few times, then `docker compose down`
   (no `-v`) and `make up` again. Counter kept? Now `make reset`. Kept?
3. **Tabs.** Replace the Tab at the start of a recipe line with spaces. Run `make up`.
4. **Missing variable.** Comment out `HELLO_PORT` in `.env`, run `docker compose config`.
5. **Runtime off.** `colima stop` (or quit OrbStack/Docker Desktop), then `make doctor`.
6. **localhost confusion.** `docker compose exec hello python -c "import urllib.request as u; print(u.urlopen('http://localhost:8088').read())"`
   — why does this fail when the same URL works from your Mac? Which URL works?

---

## 4. Done when

- [ ] `make check-m00` passes
- [ ] Journal answered (no `TODO` left in it)
- [ ] Ask Claude to review your changes
- [ ] Commit, then tag: `git tag m00-foundations`
