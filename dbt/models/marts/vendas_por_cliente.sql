-- vendas_por_cliente.sql
-- Mart (camada de negócio): total gasto por cliente.
-- Note a função ref() abaixo: é assim que o dbt sabe que este model depende
-- de stg_vendas e stg_clientes, e os roda ANTES deste.

with vendas as (
    select * from {{ ref('stg_vendas') }}
),

clientes as (
    select * from {{ ref('stg_clientes') }}
)

select
    c.id_cliente,
    c.nome,
    c.cidade,
    count(v.id_venda)  as qtd_compras,
    sum(v.valor)       as total_gasto
from clientes c
left join vendas v on v.id_cliente = c.id_cliente
group by 1, 2, 3
