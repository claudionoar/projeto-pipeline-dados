-- stg_clientes.sql
-- Staging da tabela raw de clientes: padroniza nomes e tipos.

with fonte as (
    select * from {{ source('raw', 'clientes') }}
)

select
    cast(id_cliente as integer) as id_cliente,
    trim(nome)                  as nome,
    lower(trim(email))          as email,
    trim(cidade)                as cidade
from fonte
where id_cliente is not null
