# Dockerfile
# Base: imagem oficial do Airflow. Adiciona os providers (via constraints oficiais,
# garantindo compatibilidade) e instala o dbt num virtualenv ISOLADO — assim as
# dependências do dbt não conflitam com as do Airflow (que é a causa do erro).
FROM apache/airflow:2.9.3-python3.11

USER airflow

# 1) Providers do Airflow, usando o constraint file oficial do Airflow 2.9.3.
#    O constraint fixa versões compatíveis e evita o conflito que quebrava o build.
RUN pip install --no-cache-dir \
      "apache-airflow-providers-snowflake" \
      "apache-airflow-providers-amazon" \
      "boto3" \
      "snowflake-connector-python" \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.9.3/constraints-3.11.txt"

# 2) dbt em um virtualenv separado, fora do ambiente do Airflow.
#    O DAG chama o dbt pelo caminho completo /opt/dbt-venv/bin/dbt (já ajustado no DAG).
USER root
RUN python -m venv /opt/dbt-venv \
    && /opt/dbt-venv/bin/pip install --no-cache-dir "dbt-core==1.8.*" "dbt-snowflake==1.8.*" \
    && chown -R airflow: /opt/dbt-venv

USER airflow