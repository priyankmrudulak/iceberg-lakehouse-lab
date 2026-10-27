# Milestone 1 — The lakehouse platform + first Iceberg lessons

**What you get:** a working local lakehouse — Spark, Iceberg, S3 storage and a catalog —
plus two guided notebooks. The platform is built for you; your job is to learn Iceberg
by running the notebooks.

## Start it (first time: ~5 minutes)

**1.** Copy the new settings into your `.env`. Skip this if you created `.env` after
this milestone was added. Compare with `.env.example` — you need the lines under
`# --- Milestone 1`.

**2.** Download the sample data (~100 MB, checksum-verified):

```bash
make data
```

**3.** Start everything. The first run builds the Spark image (~2 minutes):

```bash
make up
```

**Check:** it ends with a list of URLs. `make ps` shows `hello`, `rustfs`,
`iceberg-rest` and `spark` as `(healthy)`. `storage-init` shows `Exited (0)` — that's
correct, it's a one-off job that creates the bucket.

**4.** Open Jupyter: http://localhost:8888 → `notebooks/` → `01_parquet_basics.ipynb`.

## The notebooks

| Notebook | You learn | Time |
|---|---|---|
| `01_parquet_basics` | What's inside a Parquet file, column pruning, filter pushdown, statistics, partition folders, and what plain Parquet *can't* do | 30 min |
| `02_iceberg_first_table` | How an Iceberg table is built (metadata.json → manifest list → manifests → data files), watched file by file; hidden partitioning; file skipping; snapshots; time travel; DELETE and its cost; rollback; safe column rename | 45 min |

Run cells with **Shift + Enter** and read each **What to notice** note. Each notebook
ends with exercises. Both notebooks can be re-run from the top at any time.

## What's running

```
 your Mac (localhost)
   Jupyter :8888 · Spark UI :4040 · RustFS console :9001 · S3 API :9000 · catalog :8181
        │
 Docker network
   spark (PySpark + Jupyter) ──SQL──▶ iceberg-rest (catalog) ──▶ "where is each table's metadata?"
        └──── reads/writes Parquet + metadata files ───────────▶ rustfs (S3 bucket: warehouse)
```

| Service | Role | Databricks equivalent |
|---|---|---|
| `spark` | Runs PySpark in Jupyter. Config: `docker/spark/spark-defaults.conf` | Cluster + notebooks |
| `iceberg-rest` | Iceberg REST catalog: table name → current metadata file | Unity Catalog |
| `rustfs` | S3-compatible object storage holding all files | S3 / ADLS / DBFS |
| `storage-init` | Creates the `warehouse` bucket on first start, then exits | — |

Browse the files Iceberg writes: http://localhost:9001/rustfs/console/ — login
`lakehouse` / `lakehouse-secret-key`, bucket `warehouse`.

## Versions (all pinned)

| Component | Version | Where it's set |
|---|---|---|
| Spark (PySpark) | 4.1.3 | `docker/spark/requirements.txt` |
| Iceberg | 1.12.0 (`iceberg-spark-runtime-4.1_2.13`) | `docker/spark/Dockerfile` |
| Java | 17 | `docker/spark/Dockerfile` |
| Iceberg REST catalog | `apache/iceberg-rest-fixture:1.10.1` | `docker-compose.yml` |
| RustFS | 1.0.3 | `docker-compose.yml` |
| AWS CLI (bucket setup) | 2.38.4 | `docker-compose.yml` |

**Why RustFS, not MinIO?** MinIO's Docker images were removed from Docker Hub, so a lab
built on them can't be recreated. RustFS speaks the same S3 API and has a web console.

**Why the REST catalog fixture?** It's the Apache Iceberg project's reference REST
catalog — one small container, no setup. It stores its table pointers in SQLite on the
`catalog-data` volume. Production equivalents: Apache Polaris, Unity Catalog, AWS Glue.

## Useful commands

| Command | Does |
|---|---|
| `make urls` | Print every service URL |
| `make shell` | Interactive PySpark shell inside the Spark container |
| `make logs` | Follow all service logs |
| `make build` | Rebuild the Spark image after changing `docker/spark/` |
| `make down` | Stop everything; tables and files are kept |
| `make reset` | Stop and **delete all data** (tables, files, catalog) |

## Troubleshooting

| You see | Fix |
|---|---|
| `required variable S3_ACCESS_KEY is missing` | Step 1: copy the Milestone 1 lines from `.env.example` into `.env` |
| `make doctor` says a port is in use | Change that port in `.env` (e.g. `JUPYTER_PORT=8889`) |
| `docker buildx is missing` | `brew install docker-buildx` |
| Notebook: `FileNotFoundError ... data/raw/...` | `make data` |
| Spark UI on :4040 doesn't load | It only exists while a notebook has a Spark session. With two notebooks open, the second one's UI is on 4041 inside the container and isn't published. |
| `Table learn.yellow_trips not found` in a later cell | Run notebook 02 from the top — the first cells create the table |
| Jupyter kernel dies | Docker needs ≥ 6 GB memory: `colima start --memory 8` |
