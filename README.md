# Lakehouse Unplugged

Hands-on playground voor een **open lakehouse-stack** met Apache Spark, Apache Iceberg, MinIO, dbt, Jupyter, Polaris en Trino.  
De focus ligt op **begrijpen hoe de onderdelen samenhangen**, met een setup die vandaag stabiel werkt en tegelijk voorbereid is op wat eraan komt.

> **Status (2025)**  
> Spark schrijft Iceberg-tabellen via een **filesystem/Hadoop catalog** op MinIO (S3A).  
> Polaris draait mee als **Iceberg REST catalog en governance-laag**, maar wordt door Spark **nog niet** gebruikt voor writes.  
> Trino gebruikt Polaris wél voor read-only analytics.

---

## Wat bouw je hier?

- Docker Compose-stack met:
  - MinIO
  - Spark (master/worker)
  - Spark Thrift Server (voor dbt)
  - Polaris Catalog
  - Trino
  - JupyterLab
  - dbt runner
  - VS Code devcontainer
- Iceberg-ready object storage op MinIO (`warehouse` bucket automatisch aangemaakt)
- Voorbeeld notebooks en dbt-modellen (bronze → silver → gold)
- Feature-flag om Spark later **optioneel** via Polaris REST te laten lopen

---

## Architectuuroverzicht

Alle services draaien in één Docker-netwerk.

- **Spark**  
  - ETL, dbt, data creatie  
  - Iceberg **filesystem/Hadoop catalog**  
  - Schrijft direct naar `s3a://warehouse/`

- **Polaris**  
  - Iceberg REST catalog  
  - Principals, roles, catalog metadata  
  - Leest dezelfde Iceberg metadata  
  - Niet in de Spark write-path

- **Trino**  
  - SQL analytics  
  - Leest Iceberg tabellen **via Polaris REST**

### Architectuurschets

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

    +------------------+        JDBC        +------------------+
    | dbt Runner       | <---------------> | Spark Thrift     |
    +------------------+                   +------------------+
                                                     |
                                                     | Spark SQL
                                                     v
    +------------------+                   +------------------+
    | JupyterLab       | <---------------> | Spark Master     |
    +------------------+                   +--------+---------+
                                                     |
                                              +------v------+
                                              | Spark Worker|
                                              +-------------+
                                                     |
                                                     | S3A
    +------------------+                   +--------v--------+
    | Polaris Catalog  | <---- REST ------ | Iceberg Tables  |
    | (governance)     |                   | on MinIO        |
    +------------------+                   +--------+--------+
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

## Waarom gebruikt Spark Polaris nog niet direct?

Kort gezegd: **Spark schrijft standaard via Polaris**.

- Spark gebruikt de Polaris REST catalog voor DDL/DML en commit-coördinatie
- Metadata loopt via Polaris in plaats van direct naar filesystem
- Polaris verzorgt governance en authenticatie via OAuth2

Fallback is mogelijk:

- **Spark → Polaris REST catalog → Iceberg** (default, read/write via Polaris)
- **Spark → filesystem (S3A) → Iceberg** (alleen bij expliciete fallback)
- **Trino → Polaris → Iceberg**

Zo blijft Polaris de bron van waarheid voor metadata, terwijl een filesystem-fallback beschikbaar is voor noodgevallen.

---

## Feature-flag voor Spark (filesystem vs Polaris)

De stack ondersteunt één expliciete switch:

```bash
SPARK_CATALOG_MODE=polaris      # default (REST catalog)
# of
SPARK_CATALOG_MODE=filesystem   # fallback (direct filesystem)
```

- Wordt gezet per Spark service
- Selecteert bij startup de juiste `spark-defaults.conf`
- Maakt het mogelijk om terug te schakelen naar filesystem zonder herbouw van de stack

---

## Spark S3A support (MinIO)

- Hadoop-versie wordt tijdens de image build automatisch gedetecteerd (via `spark-submit --version`).
- De build voegt de volgende JARs toe aan `/opt/spark/jars`:
  - `hadoop-aws-${HADOOP_VERSION}.jar`
  - `aws-java-sdk-bundle-1.12.x.jar`

Voorbeeld:

```python
spark.read.json("s3a://warehouse/landing/file.json")
```

**Landingzone vs Iceberg/Polaris**

- Landingzone lezen: `s3a://...` (Hadoop S3A)
- Iceberg/Polaris warehouse: `s3://...` met `S3FileIO` (iceberg-aws-bundle)
- Zie je geen `polaris` in `SHOW CATALOGS`? Herstart de kernel of hercreëer de Jupyter service.

---

## Python version alignment

Spark executors en drivers gebruiken Python 3.11 via `/opt/py311`.

```bash
docker compose exec spark-worker bash -lc "/opt/py311/bin/python --version"
docker compose exec spark-master bash -lc "echo $PYSPARK_PYTHON"
```

---

## Polaris Spark check

Voer in een PySpark notebook/JupyterLab:

```python
print("spark.jars.packages =", spark.conf.get("spark.jars.packages", ""))
print("spark.sql.defaultCatalog =", spark.conf.get("spark.sql.defaultCatalog", ""))
print("spark.range(1).count() =", spark.range(1).count())
```

---

## Services in het kort

- **MinIO** – S3-compatible storage
- **Spark Master / Worker** – ETL en data creatie
- **Spark Thrift Server** – JDBC endpoint voor dbt
- **Polaris** – Iceberg REST catalog en governance
- **Trino** – Read-only SQL analytics
- **JupyterLab** – PySpark notebooks
- **dbt** – Transformaties (bronze → silver → gold)
- **VS Code devcontainer** – Ontwikkelomgeving

---

## Prerequisites

- Docker Desktop / Engine (Compose v2)
- ±6 GB RAM, 4 CPU cores
- macOS, Linux of Windows 11 (WSL2)
- Git
- Browser

---

## Quick start

```bash
git clone https://github.com/<org>/lakehouse-unplugged.git
cd lakehouse-unplugged
docker compose up -d --build
```

## dbt quickstart

```bash
docker compose up -d --build
docker compose exec dev bash -lc "scripts/dbt_check.sh"
docker compose exec dev bash -lc "cd dbt && dbt run -s smoke && dbt test -s smoke"
```

## Notebooks

Notebooks draaien via de **jupyter** service (niet via de dev container).

```bash
docker compose up -d jupyter
```

Open: http://localhost:8888

### Polaris bootstrap validatie

```bash
docker compose up -d polaris minio polaris-bootstrap
docker compose logs -f polaris-bootstrap
docker compose exec spark-master bash -lc "/opt/spark/bin/spark-sql -e 'SHOW CATALOGS'"
```

Stoppen:

```bash
docker compose down
```

Volledig resetten:

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
- Iceberg tables in `s3a://warehouse/`
- dbt-modellen van bronze naar gold

```bash
docker compose exec dev bash -lc "cd dbt && dbt debug"
docker compose exec dev bash -lc "cd dbt && dbt ls"
docker compose exec dev bash -lc "cd dbt && dbt run -s +smoke"
docker compose exec dev bash -lc "cd dbt && dbt test -s smoke"
```

---

## Werken met Trino

```sql
SHOW SCHEMAS FROM polaris;
SHOW TABLES FROM polaris.default;
SELECT * FROM polaris.default.jouw_tabel LIMIT 10;
```

Trino is in deze setup bewust **read-only**.

---

## Toekomstige uitbreidingen

- Spark via Polaris REST (zodra stabiel)
- Orchestration met Cosmos (Astronomer)
- Metadata & lineage met OpenMetadata
- Data quality tooling (Great Expectations / Soda)
- DuckDB voor lokale analytics en CI-checks

---

## Projectstructuur

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

