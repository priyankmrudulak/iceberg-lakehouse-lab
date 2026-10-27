# Spark + Iceberg + Jupyter in one image — this lab's "Databricks Runtime".
#
#   Python 3.12 (Debian 12)  →  Java 17  →  PySpark 4.1 (includes Spark)
#   → Iceberg jars (Spark runtime + AWS bundle for S3)  →  JupyterLab
#
# The Iceberg jars are downloaded at BUILD time and their checksums verified, so
# Spark never downloads anything when it starts (faster, works offline, reproducible).
#
# Version rule: the Iceberg runtime jar name encodes the Spark and Scala versions it
# was built for — iceberg-spark-runtime-<SPARK_MINOR>_<SCALA>. PySpark 4.1 → 4.1_2.13.
# A mismatch is the #1 cause of "ClassNotFoundException" / "NoSuchMethodError".

FROM python:3.12-slim-bookworm

ARG ICEBERG_VERSION=1.12.0
ARG SPARK_MINOR=4.1
ARG SCALA_VERSION=2.13
ARG ICEBERG_RUNTIME_SHA1=9e395e373a9a99643bf413ca1f74fa0c034887b4
ARG ICEBERG_AWS_BUNDLE_SHA1=64d5012217035a60924feb633636b744d318eb0a

# Java: Spark runs on the JVM; PySpark is a Python front end that talks to it.
RUN apt-get update \
 && apt-get install -y --no-install-recommends openjdk-17-jre-headless curl procps \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s "/usr/lib/jvm/java-17-openjdk-$(dpkg --print-architecture)" /usr/lib/jvm/java-17
# Same path on Apple Silicon (arm64) and Intel (amd64) Macs.
ENV JAVA_HOME=/usr/lib/jvm/java-17

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# With pip-installed PySpark, SPARK_HOME is the pyspark package folder.
# Spark looks for extra jars in $SPARK_HOME/jars and config in $SPARK_HOME/conf.
ENV SPARK_HOME=/usr/local/lib/python3.12/site-packages/pyspark
RUN set -eu; \
    base=https://repo1.maven.org/maven2/org/apache/iceberg; \
    rt=iceberg-spark-runtime-${SPARK_MINOR}_${SCALA_VERSION}; \
    curl -fsSL -o "$SPARK_HOME/jars/$rt-${ICEBERG_VERSION}.jar" "$base/$rt/${ICEBERG_VERSION}/$rt-${ICEBERG_VERSION}.jar"; \
    curl -fsSL -o "$SPARK_HOME/jars/iceberg-aws-bundle-${ICEBERG_VERSION}.jar" "$base/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar"; \
    echo "${ICEBERG_RUNTIME_SHA1}  $SPARK_HOME/jars/$rt-${ICEBERG_VERSION}.jar" | sha1sum -c -; \
    echo "${ICEBERG_AWS_BUNDLE_SHA1}  $SPARK_HOME/jars/iceberg-aws-bundle-${ICEBERG_VERSION}.jar" | sha1sum -c -; \
    mkdir -p "$SPARK_HOME/conf"

# Run as a normal user, not root.
RUN useradd --create-home --uid 1000 lab
USER lab
WORKDIR /home/lab/work

# Jupyter (8888) and the Spark UI (4040).
EXPOSE 8888 4040
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", \
     "--IdentityProvider.token=", "--ServerApp.password=", "--ServerApp.root_dir=/home/lab/work"]
