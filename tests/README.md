# Como conferir as mudanças com os testes

Os testes usam dados inventados para verificar as regras sem acessar as APIs,
o Databricks ou a base real do Supabase. Execute os comandos na raiz do projeto,
exceto quando o exemplo indicar outra pasta.

## Testes de dados com Python

```powershell
python -m unittest discover -s tests -v
```

O resultado esperado é `OK`. Se o PySpark não estiver instalado, os testes que
dependem dele aparecem como `skipped`: foram pulados, não executados.
Para rodá-los, o ambiente precisa de PySpark e Java compatíveis entre si. Nesta
contribuição, foram conferidos com PySpark 4.3.0 e Java 21.

Se o PySpark estiver instalado, mas o Java estiver ausente ou incompatível, a
inicialização do Spark pode falhar. Isso precisa ser resolvido no ambiente antes
de executar os testes de transformação.

| Arquivo | O que verifica |
|---|---|
| `test_dados.py` | Seleção de arquivos, colunas exportadas, comparação de conteúdo, atualização de registros, modo `prepare`, sintaxe e acentuação dos notebooks. |
| `test_dados_spark.py` | Movimentos do mesmo documento, valores negativos, zeros à esquerda, fallback de proposições, resultados desconhecidos, piloto e consultas de 2025. |

Por exemplo, o teste de despesas cria três movimentos do mesmo documento:
R$ 100,00, −R$ 20,00 e −R$ 20,00. Ele espera três IDs de movimento e total de
R$ 60,00. As duas linhas iguais são mantidas porque ainda não existe uma regra
da fonte que autorize descartar uma delas.

## Testes do backend com Go

```powershell
cd 05_Aplicacao/backend
go test ./internal/...
go vet ./...
```

Os testes em `internal/graphql/data_contract_test.go` conferem que um resultado
de votação desconhecido continua nulo e que um valor monetário ausente não vira
zero. Esses comandos não precisam de banco de dados.

Os testes de integração existentes em `cmd/api` são diferentes: precisam de
`DATABASE_URL` e acesso ao PostgreSQL. Não os confunda com os testes locais acima.

## O que os testes locais não comprovam

Eles não medem a cobertura da coleta real, a ocupação do disco do Supabase nem
confirmam a conclusão de uma carga no ambiente do projeto. Para isso, siga o
[procedimento de validação da carga](../03_Gold/METODOLOGIA_DADOS.md#primeira-carga-corrigida-ordem-de-execução).
O teste de atualização usa SQLite com adaptação da sintaxe; as consultas de
validação usam Spark com adaptação do nome das tabelas e do calendário. A execução
no PostgreSQL real continua necessária antes de publicar a nova base.
