# Como preparar as tabelas no PostgreSQL

Uma **migration** é um script SQL que cria ou altera a estrutura do banco.
Os scripts desta pasta são para PostgreSQL/Supabase. Execute-os no SQL Editor
do Supabase, não em uma célula SQL do Databricks.

## O que cada arquivo faz

| Arquivo | Função |
|---|---|
| `001_initial_schema_supabase.sql` | Cria as 26 tabelas, suas chaves, relações e índices em uma base vazia. |
| `002_add_autoria_principal.sql` | Adiciona o campo que diferencia o autor principal dos demais signatários. Também cria o índice usado nas consultas. |
| `003_preservar_movimentos_e_contexto.sql` | Adiciona documento de origem, restituição, resultado original da votação e partido/UF do voto. |

Chave primária (**PK**) identifica um registro. Chave estrangeira (**FK**) garante
que uma referência a outra tabela exista. Por exemplo, cada voto deve apontar
para uma votação. A migration inicial define 60 dessas relações.

## Para a primeira carga corrigida

1. Prepare uma base separada, preservando a anterior para comparação.
2. Execute `001_initial_schema_supabase.sql` no schema `public` vazio. Schema é
   o agrupamento de tabelas; `public` é o usado pela aplicação.
3. Execute `002_add_autoria_principal.sql` e depois
   `003_preservar_movimentos_e_contexto.sql`. Esses dois scripts podem ser
   executados novamente sem duplicar as colunas.
4. Siga o [guia da exportação](../../export/README.md): `prepare`, `pilot` e `full`.

O exportador não executa migrations automaticamente. Não use os blocos `DROP`
do script inicial para testar a atualização de uma base com dados: eles apagam tabelas.

## Se a estrutura do banco já existir

A `001` é para uma base vazia. Em uma base existente, as alterações de estrutura
são feitas pelas migrations `002` e `003`.

A `003` só acrescenta campos: não apaga dados, não corrige resultados de votação
já classificados e não recupera movimentos descartados em cargas anteriores.
Portanto, aplicá-la não basta para corrigir a base antiga. Reconstrua Silver e Gold
a partir da Bronze preservada e carregue o resultado em uma base separada.

Para preencher apenas a autoria principal na base existente, após aplicar a `002`:

```powershell
cd 05_Aplicacao/backend
go run ./cmd/backfill-autoria
```

Esse comando **altera a base configurada no `.env`**. Na Câmara, marca o primeiro
signatário como principal (`ordem_assinatura = 1`). No Senado, consulta a API e
usa `IndicadorAutorPrincipal = "Sim"`. Pode ser executado novamente.
Se você reconstruir a Gold e refizer a exportação, o notebook Gold já preenche esse campo.

Consulte [Como os dados são tratados e conferidos](../../METODOLOGIA_DADOS.md)
para entender a mudança de IDs e conferir a nova carga antes de usar a aplicação.
