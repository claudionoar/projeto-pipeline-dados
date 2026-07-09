-- snowflake_setup.sql
-- Rode este script UMA VEZ no Snowflake (na interface web, aba Worksheets)
-- para preparar o ambiente antes de subir o Airflow.

-- 1) Warehouse (a "máquina" que processa) e database
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60          -- desliga sozinho após 60s parado (economiza créditos)
  AUTO_RESUME = TRUE;

CREATE DATABASE IF NOT EXISTS ANALYTICS;

-- 2) Schemas: RAW recebe os dados do S3; ANALYTICS/STAGING são preenchidos pelo dbt
CREATE SCHEMA IF NOT EXISTS ANALYTICS.RAW;
CREATE SCHEMA IF NOT EXISTS ANALYTICS.STAGING;
CREATE SCHEMA IF NOT EXISTS ANALYTICS.ANALYTICS;

-- 3) Tabelas RAW (o Airflow vai carregar os CSVs do S3 aqui via COPY INTO)
CREATE TABLE IF NOT EXISTS ANALYTICS.RAW.CLIENTES (
    id_cliente STRING,
    nome       STRING,
    email      STRING,
    cidade     STRING
);

CREATE TABLE IF NOT EXISTS ANALYTICS.RAW.VENDAS (
    id_venda   STRING,
    id_cliente STRING,
    valor      STRING,
    data_venda STRING
);

-- 4) Formato de arquivo e External Stage apontando para o bucket S3
CREATE FILE FORMAT IF NOT EXISTS ANALYTICS.RAW.CSV_FORMAT
  TYPE = CSV
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1;            -- pula a linha de cabeçalho do CSV

-- Troque o URL, KEY e SECRET pelos seus valores reais.
CREATE STAGE IF NOT EXISTS ANALYTICS.RAW.S3_STAGE
  URL = 's3://meu-bucket-modelagem-ifg/'
  CREDENTIALS = (AWS_KEY_ID = 'SUA_KEY' AWS_SECRET_KEY = 'SEU_SECRET')
  FILE_FORMAT = ANALYTICS.RAW.CSV_FORMAT;
