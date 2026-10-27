# Iceberg Lakehouse Lab

A hands-on lab for learning how a Databricks-style lakehouse works, built entirely
from open-source parts and running locally on a Mac.

**Stack:** Apache Spark 4.1 (PySpark) · Apache Iceberg 1.12 · Parquet ·
RustFS (S3-compatible storage) · Iceberg REST catalog · JupyterLab

## Quickstart

Requirements: macOS (Apple Silicon or Intel), Homebrew, git and make
(`xcode-select --install`), ~15 GB free disk, Docker with ≥ 6 GB memory.

```bash
git clone https://github.com/priyankmrudulak/iceberg-lakehouse-lab.git
cd iceberg-lakehouse-lab
cp .env.example .env     # then set HELLO_PORT=8090
make doctor              # checks your Mac is ready (see Milestone 0 to install Docker)
make data                # download sample data (~100 MB)
make up                  # start the lakehouse
```

Open http://localhost:8888 and start with `notebooks/01_parquet_basics.ipynb`.
Run `make help` for all commands.

## Milestones

Each milestone is tagged in git (`git checkout m00-foundations`) so you can start from any point.

| # | Milestone | Guide | Status |
|---|---|---|---|
| 0 | Docker, Compose, Makefile, preflight checks | [m00](docs/milestones/m00-foundations.md) | ✅ |
| 1 | Lakehouse platform + Parquet basics + first Iceberg table | [m01](docs/milestones/m01-iceberg-platform.md) | ✅ |
| 2 | Bronze → silver → gold pipeline | | ⏳ |
| 3 | MERGE INTO, SCD Type 2, idempotent re-runs | | ⏳ |
| 4 | Schema and partition evolution | | ⏳ |
| 5 | Table maintenance: compaction, snapshot expiry, copy-on-write vs merge-on-read | | ⏳ |
| 6 | Orchestration with Airflow | | ⏳ |
| 7 | Data quality checks | | ⏳ |
| 8 | Trino + Superset: other engines on the same tables | | ⏳ |
| 9 | Structured Streaming into Iceberg | | ⏳ |
| 10 | CI and packaging | | ⏳ |
