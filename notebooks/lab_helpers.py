"""Small helpers shared by the lab notebooks.

    from lab_helpers import get_spark, s3_tree, s3_json

get_spark()  starts (or reuses) a SparkSession. All Iceberg and S3 settings come from
             docker/spark/conf/spark-defaults.conf, so there is nothing to configure here.
s3_tree()    prints the files under an S3 prefix, grouped by folder, so you can see
             exactly what Iceberg wrote.
s3_ls()      lists files under a prefix as (key, size) pairs.
s3_json()    opens a JSON file in S3 (e.g. an Iceberg metadata.json) as a dict.
scan_report() runs a query and reports how many Iceberg data files it read vs skipped.
"""

import json
import os
from collections import OrderedDict

import boto3
from pyspark.sql import SparkSession

BUCKET = "warehouse"
S3_ENDPOINT = "http://rustfs:9000"  # service name, not localhost: we're inside Docker


def get_spark(app_name: str = "lab") -> SparkSession:
    spark = SparkSession.builder.appName(app_name).getOrCreate()
    spark.sparkContext.setLogLevel("ERROR")  # hide Spark's INFO/WARN chatter

    # Each notebook runs its own Spark, so each has its own UI. The first takes port
    # 4040; if another notebook already has it, Spark moves to 4041, 4042, ...
    ui = spark.sparkContext.uiWebUrl  # e.g. http://<container-id>:4041 (inside Docker)
    if ui:
        port = int(ui.rsplit(":", 1)[1])
        mac_port = os.environ.get("SPARK_UI_PORT", "4040") if port == 4040 else port
        print(f"Spark UI for this notebook: http://localhost:{mac_port}")
    return spark


def _client():
    # Credentials come from the AWS_* environment variables set in docker-compose.yml.
    return boto3.client("s3", endpoint_url=S3_ENDPOINT)


def s3_ls(prefix: str, bucket: str = BUCKET) -> list[tuple[str, int]]:
    """All files under prefix, as (key, size_in_bytes), sorted by key."""
    files = []
    for page in _client().get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefix):
        files += [(o["Key"], o["Size"]) for o in page.get("Contents", [])]
    return sorted(files)


def _size(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024


def s3_tree(prefix: str, bucket: str = BUCKET, max_files: int = 6) -> None:
    """Print files under prefix grouped by folder: count, total size, first few names."""
    files = s3_ls(prefix, bucket)
    if not files:
        print(f"s3://{bucket}/{prefix}  (empty)")
        return
    groups: "OrderedDict[str, list]" = OrderedDict()
    for key, size in files:
        folder, _, name = key.rpartition("/")
        groups.setdefault(folder, []).append((name, size))
    total = sum(s for _, s in files)
    print(f"s3://{bucket}/{prefix}  —  {len(files)} files, {_size(total)}, {len(groups)} folders")
    shown = 0
    for folder, items in groups.items():
        if shown >= 12:
            print(f"  ... and {len(groups) - shown} more folders")
            break
        print(f"  {folder}/  ({len(items)} files, {_size(sum(s for _, s in items))})")
        for name, size in items[:max_files]:
            print(f"      {name:<80} {_size(size):>9}")
        if len(items) > max_files:
            print(f"      ... {len(items) - max_files} more")
        shown += 1


def scan_report(df) -> dict:
    """Run df and report how much of the Iceberg table Spark actually read.

    Reads the same per-scan metrics the Spark UI shows on its SQL tab:
    files scanned vs skipped, manifests scanned, bytes read.
    """
    from pyspark.sql import functions as F

    # sum(1) forces a real scan. (A plain count() can be answered by Iceberg from
    # its metadata alone, without reading any data file.)
    probe = df.agg(F.sum(F.lit(1)).alias("rows"))
    rows = probe.collect()[0]["rows"] or 0

    wanted = {
        "resultDataFiles": "data_files_read",
        "skippedDataFiles": "data_files_skipped",
        "scannedDataManifests": "manifests_read",
        "totalDataManifest": "manifests_total",
        "totalDataFileSize": "bytes_read",
        "resultDeleteFiles": "delete_files_read",
    }
    report = {"rows": rows}

    def walk(node):
        name = node.getClass().getSimpleName()
        if "Scan" in name:
            metrics = node.metrics()
            for key, label in wanted.items():
                if metrics.contains(key):
                    report[label] = report.get(label, 0) + metrics.apply(key).value()
        if name.endswith("QueryStageExec"):
            walk(node.plan())
        if name == "AdaptiveSparkPlanExec":
            walk(node.finalPhysicalPlan())
        children = node.children()
        for i in range(children.size()):
            walk(children.apply(i))

    walk(probe._jdf.queryExecution().executedPlan())
    if "bytes_read" in report:
        report["MB_read"] = round(report.pop("bytes_read") / 1024 / 1024, 1)
    return report


def s3_json(key: str, bucket: str = BUCKET) -> dict:
    """Read a JSON file from S3. Accepts a key or a full s3://bucket/key path."""
    if key.startswith("s3://"):
        bucket, _, key = key[len("s3://"):].partition("/")
    body = _client().get_object(Bucket=bucket, Key=key)["Body"].read()
    return json.loads(body)
