from datetime import datetime

from cosmos import DbtDag, ExecutionConfig, ProfileConfig, ProjectConfig

DBT_PROJECT_PATH = "/opt/airflow/dbt_project"
DBT_PROFILES_YML = "/opt/airflow/dbt/profiles.yml"


dbt_cosmos = DbtDag(
    dag_id="dbt_cosmos",
    schedule=None,
    start_date=datetime(2025, 1, 1),
    catchup=False,
    project_config=ProjectConfig(DBT_PROJECT_PATH),
    profile_config=ProfileConfig(
        profile_name="lakehouse_unplugged",
        target_name="dev",
        profiles_yml_filepath=DBT_PROFILES_YML,
    ),
    execution_config=ExecutionConfig(
        execution_mode="docker",
        docker_image="dbt",
        docker_network_mode="lakehouse-unplugged_lakehouse",
    ),
)
