# Iceberg Lakehouse Lab

A hands-on lab for learning how a Databricks-style lakehouse works, built entirely
from open-source parts and running locally on a Mac.

**Core stack:** Apache Spark (PySpark) · Apache Iceberg · Parquet · MinIO (S3) ·
Iceberg REST catalog — with optional Airflow, Trino, Superset and streaming add-ons.

> Status: under construction. The lab is being built milestone by milestone;
> each milestone is tagged in git so you can start from any point.

## Requirements

- macOS (Apple Silicon or Intel)
- Docker (OrbStack, Docker Desktop or Colima)
- git and make (`xcode-select --install`)

## Milestones

| # | Milestone | Status |
|---|---|---|
| 0 | Docker, Compose, Makefile, preflight checks | ⏳ |
| 1 | Parquet with plain PySpark | ⏳ |
| 2 | Custom Spark + Iceberg image | ⏳ |
| 3 | Iceberg tables on a local folder | ⏳ |
| 4 | MinIO object storage | ⏳ |
| 5 | Iceberg REST catalog | ⏳ |
| 6 | Bronze → silver → gold pipeline | ⏳ |
| 7 | MERGE INTO, SCD Type 2, idempotency | ⏳ |
| 8 | Time travel, schema and partition evolution | ⏳ |
| 9 | Table maintenance | ⏳ |
| 10 | Orchestration with Airflow | ⏳ |
| 11 | Data quality checks | ⏳ |
| 12 | Trino + Superset | ⏳ |
| 13 | Structured Streaming | ⏳ |
| 14 | CI and packaging | ⏳ |
