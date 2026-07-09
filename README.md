# Pipeline de Dados — Airflow + dbt + Snowflake + S3

Projeto didático da disciplina de Modelagem de Dados (Pós IFG).
Um pipeline ELT completo: os dados vão do **S3** para o **Snowflake**, são transformados
pelo **dbt** e tudo é orquestrado pelo **Airflow**, rodando em Docker.

## Arquitetura

```
Airflow (orquestra)
   │
   ├─ 1. upload_to_s3 ......... envia CSVs locais para o bucket S3
   ├─ 2. copy_into_snowflake .. COPY INTO das tabelas RAW no Snowflake
   ├─ 3. run_dbt .............. transforma (staging -> marts)
   └─ 4. test_dbt ............. roda testes de qualidade
```

## Estrutura de pastas

```
.
├── docker-compose.yml       # sobe Airflow + Postgres + dbt
├── Dockerfile               # imagem com Airflow + dbt instalados juntos
├── .env.example             # modelo de credenciais (copie para .env)
├── snowflake_setup.sql      # rode 1x no Snowflake antes de tudo
├── dags/
│   └── pipeline_modelagem.py # o DAG que amarra tudo
├── dbt/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   └── models/
│       ├── staging/         # limpeza (1 model por fonte)
│       └── marts/           # tabelas de negócio
└── data/
    ├── clientes.csv
    └── vendas.csv
```

## Pré-requisitos

- Docker e Docker Compose instalados
- Conta gratuita no Snowflake (trial de 30 dias em signup.snowflake.com)
- Conta AWS com um bucket S3 e um par de chaves (Access Key / Secret Key)

## Passo a passo

### 1. Configurar credenciais
```bash
cp .env.example .env
# edite o .env com seus dados reais do Snowflake e da AWS
```

### 2. Preparar o Snowflake
Abra o Snowflake (Worksheets) e rode o conteúdo de `snowflake_setup.sql`.
Lembre de trocar o URL do bucket e as chaves AWS no comando CREATE STAGE.

### 3. Criar o bucket S3
Crie um bucket na AWS com o mesmo nome que você colocou em `S3_BUCKET` no `.env`.
(O Airflow vai fazer o upload dos CSVs; você não precisa subir nada manualmente.)

### 4. Subir o ambiente
```bash
docker compose build          # constrói a imagem (Airflow + dbt)
docker compose up airflow-init  # inicializa o banco e cria o usuário admin
docker compose up -d          # sobe webserver + scheduler
```

### 5. Acessar o Airflow
Abra http://localhost:8080 — usuário `admin`, senha `admin`.
Ative o DAG `pipeline_modelagem` e clique em "Trigger" (o gatilho) para rodar na hora.

### 6. Ver o resultado
No Snowflake, consulte a tabela final gerada pelo dbt:
```sql
SELECT * FROM ANALYTICS.ANALYTICS.VENDAS_POR_CLIENTE;
```

## Comandos úteis do dbt (rodando dentro do container)
O dbt fica num virtualenv isolado (`/opt/dbt-venv`), então use o caminho completo:
```bash
docker compose exec airflow-scheduler bash
cd /opt/airflow/dbt
/opt/dbt-venv/bin/dbt debug     # testa a conexão com o Snowflake
/opt/dbt-venv/bin/dbt run       # roda os models
/opt/dbt-venv/bin/dbt test      # roda os testes
/opt/dbt-venv/bin/dbt docs generate && /opt/dbt-venv/bin/dbt docs serve
```

## Parar tudo
```bash
docker compose down          # para os containers
docker compose down -v       # para e apaga os volumes (reset total)
```
