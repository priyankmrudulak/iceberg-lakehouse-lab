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

**4.** Open Jupyter: http://localhost:8888 → `notebooks/` → `00_spark_basics.ipynb`.

## The notebooks

| Notebook | You learn | Time |
|---|---|---|
| `00_spark_basics` | **Start here if Spark is new.** Notebooks, SparkSession, DataFrames, lazy evaluation, SQL vs DataFrame API side by side, joins, partitions/tasks/shuffles, `explain()` and the Spark UI, a Python cheat sheet | 45 min |
| `01_parquet_basics` | What's inside a Parquet file, column pruning, filter pushdown, statistics, partition folders, and what plain Parquet *can't* do | 30 min |
| `02_iceberg_first_table` | How an Iceberg table is built (metadata.json → manifest list → manifests → data files), watched file by file; hidden partitioning; file skipping; snapshots; time travel; DELETE and its cost; rollback; safe column rename | 45 min |

Run cells with **Shift + Enter**. Before each code cell, **What this cell does** explains
the code line by line; after it, **What to notice** explains the result. Each notebook
ends with exercises, and every notebook can be re-run from the top at any time.

## Coming from Hive / Impala

If you know the Hadoop stack, most of this lab is familiar ideas on newer tools. The
notebooks have a **Coming from Hive/Impala** note wherever a concept maps to one you know.

| You know (Hadoop) | In this lab | What's different |
|---|---|---|
| HDFS | S3 object storage (RustFS) | No real folders, just keys. Storage is separate from compute; no NameNode |
| Hive metastore | Iceberg REST catalog | Stores only a pointer to each table's current metadata file — not partitions or files |
| Hive table = a folder | Iceberg table = files + metadata | Iceberg lists every file itself: no `MSCK REPAIR` / `REFRESH`, no slow folder listing |
| `PARTITIONED BY (dt STRING)` | `PARTITIONED BY (days(ts))` | Hidden partitioning: no extra column to fill in or remember to filter on |
| `COMPUTE STATS` | automatic | Per-file min/max and row counts recorded on every write |
| `INSERT OVERWRITE` a partition | `DELETE` / `UPDATE` / `MERGE INTO` | Atomic, row-level, and undoable with rollback |
| HDFS snapshots | Snapshots + time travel | Every write is a version; `VERSION AS OF` is just SQL |
| `ALTER TABLE CHANGE COLUMN` | `ALTER TABLE RENAME COLUMN` | Columns tracked by ID, so old files never go NULL |
| Impala / Hive SQL | Spark SQL | Nearly the same SQL dialect |
| Hue / beeline | Jupyter notebooks | Query, results and explanations in one page |
| `SHOW FILES` / `SHOW PARTITIONS` | `table.files` / `table.partitions` | Metadata tables you can query and join |

**SQL or Python?** Both. PySpark (Python) runs Spark; inside it, `spark.sql("...")`
runs ordinary SQL. Most Iceberg features are SQL commands, so you can do most of the lab
in SQL. The notebooks show the SQL equivalent next to Python DataFrame code.

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
| `spark` | Runs PySpark in Jupyter. Config: `docker/spark/conf/spark-defaults.conf` | Cluster + notebooks |
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
| `docker buildx is missing` | `brew install docker-buildx`, then `make docker-config` |
| Notebook: `FileNotFoundError ... data/raw/...` | `make data` |
| Spark UI doesn't load | It only exists while a notebook has a Spark session. Each open notebook gets its own UI: the first on 4040, then 4041–4043. Use the link `get_spark()` prints. |
| `Table learn.yellow_trips not found` in a later cell | Run notebook 02 from the top — the first cells create the table |
| Jupyter kernel dies | Docker needs ≥ 6 GB memory: `colima start --memory 8` |
