# Iceberg Lakehouse Lab

A hands-on lab for learning how a Databricks-style lakehouse works, built entirely
from open-source parts and running locally on a Mac.

**Stack:** Apache Spark 4.1 (PySpark) · Apache Iceberg 1.12 · Parquet ·
RustFS (S3-compatible storage) · Iceberg REST catalog · JupyterLab

## Quickstart (from a fresh Mac)

**You need:** macOS 13 or newer (Apple Silicon or Intel), ~15 GB free disk, 8 GB RAM or
more (16 GB recommended), and an internet connection. Allow ~20 minutes the first time.

Run each command in **Terminal** (Applications → Utilities → Terminal).

**1. Install Apple's command line tools** (gives you `git` and `make`). A window pops up;
click Install. If it says they're already installed, go on.

```bash
xcode-select --install
```

**2. Install Homebrew** (the Mac package manager). Skip if `brew --version` already works.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

When it finishes, it prints **"Next steps"** with two commands to run (they add `brew`
to your PATH). Run them, then close and reopen Terminal.

**3. Install Docker** (via Colima, a free Docker runtime for macOS) **and its plugins:**

```bash
brew install colima docker docker-compose docker-buildx
```

**4. Download the lab:**

```bash
git clone https://github.com/priyankmrudulak/iceberg-lakehouse-lab.git
```

```bash
cd iceberg-lakehouse-lab
```

**5. Let Docker find the Compose and buildx plugins** (safely adds one line to
`~/.docker/config.json`, keeping anything already there):

```bash
make docker-config
```

**6. Start the Docker virtual machine.** On a Mac with 16 GB RAM or more:

```bash
colima start --cpu 4 --memory 8 --disk 60 --vm-type vz
```

With 8 GB RAM, use `--memory 6` instead. On Apple Silicon you can add `--vz-rosetta` for
faster Intel-only images (optional).

**7. Check everything is ready.** Every line should be a green ✔, ending with `Ready`.
If a line is red, it prints the fix.

```bash
make doctor
```

**8. Download the sample data** (~100 MB, NYC taxi trips, checksum-verified):

```bash
make data
```

**9. Start the lab.** The first time, it builds the Spark image (2–5 minutes); after
that it starts in seconds. It ends by printing the URL of every service.

```bash
make up
```

**10. Open Jupyter** at http://localhost:8888 → `notebooks/` → **`00_spark_basics.ipynb`**.
Then do `01` and `02`. The [Milestone 1 guide](docs/milestones/m01-iceberg-platform.md)
explains what's running and what each notebook teaches.

### Already have Docker Desktop or OrbStack?
Skip steps 3, 5 and 6 — they include Compose and buildx. Make sure the app is running,
then continue from step 4 (clone) and step 7 (`make doctor`).

### Every day after setup

| To | Run |
|---|---|
| Start Docker (after a reboot) | `colima start` |
| Start the lab | `make up` |
| Stop the lab (your tables and files are kept) | `make down` |
| Stop Docker | `colima stop` |
| See all commands | `make help` |

`.env` is created automatically from `.env.example` on the first `make up`. Change a port
there only if `make doctor` says it's taken.

## Milestones

Each milestone is tagged in git (`git checkout m00-foundations`) so you can start from any point.

| # | Milestone | Guide |
|---|---|---|
| 0 | Docker, Compose, Makefile, preflight checks | [m00](docs/milestones/m00-foundations.md) |
| 1 | Lakehouse platform + Spark basics + Parquet basics + first Iceberg table | [m01](docs/milestones/m01-iceberg-platform.md) |
| 2 | Bronze → silver → gold pipeline | |
| 3 | MERGE INTO, SCD Type 2, idempotent re-runs | |
| 4 | Schema and partition evolution | |
| 5 | Table maintenance: compaction, snapshot expiry, copy-on-write vs merge-on-read | |
| 6 | Orchestration with Airflow | |
| 7 | Data quality checks | |
| 8 | Trino + Superset: other engines on the same tables | |
| 9 | Structured Streaming into Iceberg | |
| 10 | CI and packaging | |
