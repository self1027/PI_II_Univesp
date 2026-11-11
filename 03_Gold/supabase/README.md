# Supabase — Migração Gold → PostgreSQL

Esta pasta contém a migration SQL que implementa o modelo relacional LegisAnalytica v5 no PostgreSQL do Supabase.

## Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `migrations/001_initial_schema_supabase.sql` | Esquema inicial: 26 tabelas, PKs, FKs, índices e comentários |

## Pré-requisitos

- Projeto Supabase criado e ativo
- Secret Scope `legisanalytica_supabase` no Databricks com chaves `jdbc_url`, `user`, `password`
- Notebook de exportação: `../export/EXPORT_supabase_postgresql.ipynb`

## Aplicar a migration

1. Abrir o SQL Editor do Supabase (Dashboard → SQL Editor)
2. Colar o conteúdo de `001_initial_schema_supabase.sql`
3. Executar em banco vazio (fresh database)
4. Para re-executar, descomentar o bloco `DROP TABLE` no topo do arquivo

## Ordem topológica de criação

As 26 tabelas são criadas em 6 níveis de dependência de FK:

| Nível | Tabelas |
|-------|--------|
| 0 | lote, casa, uf, legislatura, partido, tipo_proposicao |
| 1 | causa_afastamento, parlamentar, tipo_voto, tipo_despesa |
| 2 | identificador_parlamentar, cadastro_observado, parlamentar_legislatura, mandato, fornecedor, proposicao |
| 3 | vinculo_mandato, autoria, status_atual, votacao, despesa, total_publicado |
| 4 | exercicio, votacao_proposicao, valor_despesa |
| 5 | voto |

## Decisões de modelagem

- `despesa.codigo_tipo`: admite NULL (329 registros do Senado sem tipo de despesa)
- `despesa.id_parlamentar`: **sem FK** para `parlamentar` (código CEAP, não API; resolução via `identificador_parlamentar`)
- `identificador_parlamentar.id_parlamentar`: admite NULL (216 CEAPs sem mapeamento API)
- FKs com colunas NULLABLE usam `MATCH SIMPLE` (padrão PostgreSQL)
- `lote`: constraints `UNIQUE` adicionais em `entidade_fonte` e em `hash_sha256`
- Índices criados em todas as colunas de FK não cobertas pelo prefixo da PK
- A aplicação é manual, no SQL Editor do Supabase; o exportador não executa DDL.

Consulte o [README das migrations](migrations/README.md) para aplicar também as
migrations `002` e `003` e preparar a primeira carga corrigida em base separada.
