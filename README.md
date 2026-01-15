# Lakehouse Unplugged

Hands-on playground for an **open lakehouse stack** with Apache Spark, Apache Iceberg, MinIO, dbt, Jupyter, Polaris, and Trino.
The focus is on **understanding how the components fit together**, with a setup that works today and can evolve as the stack matures.

> **Project Status (2026)**
> Spark writes Iceberg tables via the Polaris REST catalog (default).
> Polaris provides the Iceberg REST catalog and governance layer.
> dbt is up and running, with models for Silver and Gold.
> Jupyter works against Spark for interactive development and testing.
> Trino uses Polaris for read-only analytics.
> Airflow services are included but **not yet functionally integrated** (work in progress).
> A filesystem/Hadoop fallback is available if needed.
> 
> Together this forms a laptop-first, fully working end-to-end stack.
> Future improvements are described in the “Future extensions” paragraph.

---

## What do you build here?

- Docker Compose stack with:
  - MinIO
  - Spark (master/worker)
  - Spark Thrift Server (for dbt)
  - Polaris Catalog
  - Trino
  - JupyterLab
  - dbt runner (scheduled runs)
  - VS Code devcontainer
  - Airflow services (work in progress)
- Iceberg-ready object storage on MinIO (`warehouse` bucket created automatically)
- Example notebooks and dbt models (bronze → silver → gold)
- Feature flag to switch Spark between Polaris REST and filesystem mode

---

## Architecture overview

All services run in a single Docker network.

- **dbt**
  - Scheduled runs via the **dbt service** (Spark Thrift JDBC)
  - Development/authoring via **dbt in the devcontainer**

- **Spark**
  - ETL, dbt, data creation
  - Iceberg via **Polaris REST catalog** (default)
  - Writes to `s3://warehouse/` with Iceberg S3FileIO

- **Polaris**
  - Iceberg REST catalog
  - Principals, roles, catalog metadata
  - Governance layer for catalog access

- **Trino**
  - SQL analytics
  - Reads Iceberg tables **via Polaris REST** (read-only)

- **Airflow**
  - Services present but **not yet functionally integrated** (work in progress)

### Architecture sketch

```
                   Host (VS Code / CLI / Browser)
                                |
                         VS Code / Ports
                                |
                        +----------------+
                        | Devcontainer   |
                        | /workspace    |
                        +--------+-------+
                                 |
    ---------------------------------------------------------
    Docker Compose Network
    ---------------------------------------------------------

    +------------------+        JDBC       +------------------+
    | dbt Runner       | <---------------> | Spark Thrift     |
    | (scheduled runs) |                   +------------------+
    +------------------+                             |
                                                     |
    +------------------+                             |
    | Airflow          |                             |
    | (WIP)            |                             |
    +------------------+                             |
                                                     |
                                                     | Spark SQL
                                                     v
    +------------------+                    +------------------+
    | JupyterLab       | <----------------> | Spark Master     |
    +------------------+                    +--------+---------+
                                                     |
                                              +------v------+
                                              | Spark Worker|
                                              +-------------+
                                                     |
                                                     | S3A / S3FileIO
    +------------------+                    +--------v--------+
    | Polaris Catalog  | <---- REST ------- | Iceberg Tables  |
    | (governance)     |                    | on MinIO        |
    +------------------+                    +--------+--------+
              |                                      |
              |                               +------v------+
              | REST                          |   MinIO     |
              |                               +-------------+
              v
    +------------------+
    | Trino            |
    | (read-only SQL)  |
    +--------+---------+
```

---

## Why keep a filesystem fallback?

Polaris is the default path for Spark writes, but a filesystem/Hadoop fallback is available for recovery or troubleshooting:

- **Spark → Polaris REST catalog → Iceberg** (default read/write)
- **Spark → filesystem (S3A) → Iceberg** (explicit fallback)
- **Trino → Polaris → Iceberg** (read-only)

This keeps Polaris as the source of truth for catalog metadata while preserving a reliable fallback option.

---

## Feature flag for Spark (filesystem vs Polaris)

The stack supports an explicit switch:

```bash
SPARK_CATALOG_MODE=polaris      # default (REST catalog)
# or
SPARK_CATALOG_MODE=filesystem   # fallback (direct filesystem)
```

- Set per Spark service
- Selects the correct `spark-defaults.conf` at startup
- Allows fallback without rebuilding the stack

---

## Spark S3A support (MinIO)

- The Hadoop version is detected during image build (via `spark-submit --version`).
- The build adds these JARs to `/opt/spark/jars`:
  - `hadoop-aws-${HADOOP_VERSION}.jar`
  - `aws-java-sdk-bundle-1.12.x.jar`

Example:

```python
spark.read.json("s3a://warehouse/landing/file.json")
```

**Landing zone vs Iceberg/Polaris**

- Landing zone reads: `s3a://...` (Hadoop S3A)
- Iceberg/Polaris warehouse: `s3://...` with `S3FileIO` (iceberg-aws-bundle)
- Don’t see `polaris` in `SHOW CATALOGS`? Restart the kernel or recreate the Jupyter service.

---

## Python version alignment

Spark executors and drivers use Python 3.11 via `/opt/py311`.

```bash
docker compose exec spark-worker bash -lc "/opt/py311/bin/python --version"
docker compose exec spark-master bash -lc "echo $PYSPARK_PYTHON"
```

---

## Polaris Spark check

Run this in a PySpark notebook/JupyterLab:

```python
print("spark.jars.packages =", spark.conf.get("spark.jars.packages", ""))
print("spark.sql.defaultCatalog =", spark.conf.get("spark.sql.defaultCatalog", ""))
print("spark.range(1).count() =", spark.range(1).count())
```

---

## Services at a glance

- **MinIO** – S3-compatible storage
- **Spark Master / Worker** – ETL and data creation
- **Spark Thrift Server** – JDBC endpoint for dbt
- **Polaris** – Iceberg REST catalog and governance
- **Trino** – Read-only SQL analytics
- **JupyterLab** – PySpark notebooks
- **dbt** – Transformations (bronze → silver → gold)
- **dbt in devcontainer** – Development/authoring environment
- **VS Code devcontainer** – Development environment
- **Airflow** – Work in progress (services present, not yet integrated)

---

## Prerequisites

- Docker Desktop / Engine (Compose v2)
- ±6 GB RAM, 4 CPU cores
- macOS, Linux, or Windows 11 (WSL2)
- Git
- Browser

---

## Quick start

```bash
git clone https://github.com/<org>/lakehouse-unplugged.git
cd lakehouse-unplugged
docker compose up -d --build
```

## dbt: run & develop

The Thrift Server bootstraps `polaris.default`, so dbt can connect without manual namespace setup.

### Development in the devcontainer (VS Code terminal)

Use this for development and authoring with dbt inside the VS Code devcontainer.

1. Start the stack (from your host shell):

```bash
docker compose up -d --build
```

2. Open the repo in VS Code and **Reopen in Container** (Command Palette → “Dev Containers: Reopen in Container”).

3. In the VS Code terminal (inside the devcontainer), run:

```bash
cd /workspace/dbt
dbt deps
dbt debug
dbt run -s smoke
dbt test -s smoke
```

#### Silver & Gold models (VS Code terminal)

```bash
dbt run  --select silver --full-refresh
dbt test --select silver --indirect-selection=empty

dbt run  --select gold --full-refresh
dbt test --select gold
```

The devcontainer uses `dbt/profiles.yml` and connects to the Spark Thrift Server at `spark-thrift:10000`.
If you update `profiles.yml`, restart the devcontainer to pick up changes.

### Scheduled runs via the dbt container (PowerShell window)

Use the **dbt service** for scheduled runs (outside the devcontainer).

```bash
docker compose up -d --build
docker compose run --rm dbt debug
docker compose run --rm dbt run -s smoke
docker compose run --rm dbt test -s smoke
```

#### Silver & Gold models (PowerShell window)

```bash
docker compose run --rm dbt run  --select silver --full-refresh
docker compose run --rm dbt test --select silver --indirect-selection=empty

docker compose run --rm dbt run  --select gold --full-refresh
docker compose run --rm dbt test --select gold
```

## Notebooks

Notebooks run through the **jupyter** service (not the dev container).

```bash
docker compose up -d jupyter
```

Register Jupyter kernel in vscode with this url: http://localhost:8888

### Polaris bootstrap validation

```bash
docker compose up -d polaris minio polaris-bootstrap
docker compose logs -f polaris-bootstrap
docker compose exec spark-master bash -lc "/opt/spark/bin/spark-sql -e 'SHOW CATALOGS'"
```

Stop:

```bash
docker compose down
```

Full reset:

```bash
docker compose down -v
```

---

## Endpoints

| Service           | URL                            |
|-------------------|--------------------------------|
| MinIO API         | http://localhost:9000          |
| MinIO Console     | http://localhost:9001          |
| Polaris API       | http://localhost:8181          |
| Polaris Health    | http://localhost:8182/q/health |
| Spark Master UI   | http://localhost:8080          |
| Spark Worker UI   | http://localhost:8081          |
| Spark Thrift      | localhost:10000                |
| JupyterLab        | http://localhost:8888          |
| Trino UI          | http://localhost:8088          |

---

## Data & workflows

- Sample data in `data/`
- Iceberg tables in `s3://warehouse/`
- dbt models from bronze to gold

```Powershell
docker compose run --rm dbt debug
docker compose run --rm dbt ls
docker compose run --rm dbt run -s +smoke
docker compose run --rm dbt test -s smoke
```

---

## Working with Trino

```sql
SHOW SCHEMAS FROM polaris;
SHOW TABLES FROM polaris.default;
SELECT * FROM polaris.default.your_table LIMIT 10;
```

```bash
docker compose exec trino trino --execute "SHOW SCHEMAS FROM polaris;"
docker compose exec trino trino --execute "SHOW TABLES FROM polaris.bronze;"
docker compose exec trino trino --execute "SELECT * FROM polaris.bronze.gekentekendevoertuigen LIMIT 10;"
```

Trino is intentionally **read-only** in this setup.

---

## Future extensions

- Polaris credential delegation & fine-grained access policies
- Orchestration with Cosmos (Astronomer)
- Metadata & lineage with OpenMetadata
- Data quality tooling (Great Expectations / Soda)
- DuckDB for local analytics and CI checks

---

## Run dbt in container

The **dbt service** is intended for **scheduled runs**. For development and authoring,
use **dbt inside the devcontainer**.

```powershell
docker compose run --rm dbt debug
docker compose run --rm dbt run
docker compose run --rm dbt test
```

## Start Airflow

```bash
docker compose up -d airflow-db airflow-init airflow-webserver airflow-scheduler airflow-triggerer
```

Airflow is still **work in progress**: the services are present but not yet functionally integrated.

Airflow UI: http://localhost:8089 (admin/admin)

## Project structure

```
.
|-- .devcontainer/
|-- data/
|-- dbt/
|-- docker/
|-- docker-compose.yml
|-- src/notebooks/
|-- .env
`-- README.md
```
