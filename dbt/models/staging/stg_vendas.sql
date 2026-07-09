-- stg_vendas.sql
-- Camada de staging: limpa e padroniza a tabela raw de vendas.
-- Um SELECT simples — o dbt transforma isso numa VIEW no Snowflake.

with fonte as (
    select * from {{ source('raw', 'vendas') }}
)

select
    cast(id_venda    as integer)      as id_venda,
    cast(id_cliente  as integer)      as id_cliente,
    cast(valor       as numeric(12,2)) as valor,
    cast(data_venda  as date)         as data_venda
from fonte
where id_venda is not null   -- descarta linhas sem chave
