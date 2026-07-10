"""
pipeline_modelagem.py — DAG que orquestra o pipeline ELT completo.

Fluxo das tasks:
  upload_to_s3  ->  copy_into_snowflake  ->  run_dbt  ->  test_dbt

Cada task faz uma etapa; o Airflow garante a ordem e re-tenta em falhas.
"""
from __future__ import annotations

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator


# ---- Task 1: enviar os CSVs locais para o bucket S3 ----
def upload_to_s3():
    import boto3
    bucket = os.environ["S3_BUCKET"]
    s3 = boto3.client("s3")
    for arquivo in ["clientes.csv", "vendas.csv"]:
        caminho_local = f"/opt/airflow/data/{arquivo}"
        s3.upload_file(caminho_local, bucket, arquivo)
        print(f"Enviado {arquivo} para s3://{bucket}/{arquivo}")


# ---- Task 2: copiar do S3 (via stage) para as tabelas RAW do Snowflake ----
def copy_into_snowflake():
    import snowflake.connector
    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ["SNOWFLAKE_ROLE"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
    )
    cur = conn.cursor()
    try:
        # Recarrega do zero (didático). Em produção você usaria carga incremental.
        cur.execute("TRUNCATE TABLE ANALYTICS.RAW.CLIENTES")
        cur.execute("TRUNCATE TABLE ANALYTICS.RAW.VENDAS")
        cur.execute("""
            COPY INTO ANALYTICS.RAW.CLIENTES
            FROM @ANALYTICS.RAW.S3_STAGE/clientes.csv
            FILE_FORMAT = (FORMAT_NAME = ANALYTICS.RAW.CSV_FORMAT)
        """)
        cur.execute("""
            COPY INTO ANALYTICS.RAW.VENDAS
            FROM @ANALYTICS.RAW.S3_STAGE/vendas.csv
            FILE_FORMAT = (FORMAT_NAME = ANALYTICS.RAW.CSV_FORMAT)
        """)
        print("COPY INTO concluído.")
    finally:
        cur.close()
        conn.close()


default_args = {
    "owner": "aluno_ifg",
    "retries": 2,                          # tenta de novo 2x se falhar
    "retry_delay": timedelta(minutes=1),
}

with DAG(
    dag_id="pipeline_modelagem",
    default_args=default_args,
    description="S3 -> Snowflake -> dbt (disciplina de modelagem IFG)",
    schedule="@daily",                     # roda uma vez por dia
    start_date=datetime(2025, 1, 1),
    catchup=False,                         # não roda datas passadas acumuladas
    tags=["ifg", "modelagem"],
) as dag:

    t1 = PythonOperator(
        task_id="upload_to_s3",
        python_callable=upload_to_s3,
    )

    t2 = PythonOperator(
        task_id="copy_into_snowflake",
        python_callable=copy_into_snowflake,
    )

    # Task 3: roda os models do dbt.
    # O dbt está num venv isolado, então chamamos pelo caminho completo.
    t3 = BashOperator(
        task_id="run_dbt",
        bash_command="cd /opt/airflow/dbt && /opt/dbt-venv/bin/dbt run",
    )

    # Task 4: roda os testes de qualidade definidos no schema.yml
    t4 = BashOperator(
        task_id="test_dbt",
        bash_command="cd /opt/airflow/dbt && /opt/dbt-venv/bin/dbt test",
    )

    # Define a ORDEM: cada seta é uma dependência
    t1 >> t2 >> t3 >> t4
