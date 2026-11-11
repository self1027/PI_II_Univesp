# Como exportar a Gold para o Supabase

O notebook `EXPORT_supabase_postgresql.ipynb` copia as 26 tabelas da Gold para o
PostgreSQL usado pela aplicação. O período de análise continua sendo **2025**.
Registros relacionados de outros anos também podem estar presentes para explicar
o histórico e manter as relações entre tabelas.

Antes de executar, leia [Como os dados são tratados e conferidos](../METODOLOGIA_DADOS.md).
Esse guia explica os IDs de movimentos, os indicadores e os termos usados aqui.

## O que precisa estar pronto

1. Silver e Gold concluídas, executadas nessa ordem.
2. Banco de destino preparado conforme o [guia das migrations](../supabase/migrations/README.md).
   O exportador não cria nem altera a estrutura das tabelas.
3. Credenciais no Secret Scope `legisanalytica_supabase`, que é o local de segredos
   do Databricks. As chaves esperadas são `jdbc_url`, `user` e `password`.
4. Biblioteca `psycopg` v3 e a biblioteca de sistema `libpq` disponíveis no ambiente.
   Instale o `psycopg` em uma célula separada, reinicie a sessão e mantenha
   `PSYCOPG_IMPL=python` antes do import, como já está no notebook.

Na primeira carga corrigida, use uma **base separada**. A versão antiga identifica
despesas da Câmara pelo documento; a nova identifica cada movimento. Misturar
esses IDs deixaria registros antigos e novos no mesmo conjunto.

## Os três modos de execução

Escolha o modo na variável `EXPORT_MODE` e execute o notebook em ordem.

| Modo | O que faz | Grava dados? |
|---|---|---|
| `prepare` | Confere origem, estrutura do banco e chaves existentes. | Não. |
| `pilot` | Carrega um conjunto pequeno com seus registros relacionados. | Sim. |
| `full` | Carrega o recorte completo e confere o resultado. | Sim. |

Comece por `prepare`. Se passar, execute `pilot` e confira os resultados antes de
executar `full`. Use o mesmo recorte ao passar do piloto para a carga completa.

O piloto seleciona até cinco despesas por Casa/ano/mês disponível e cinco votações
e proposições por Casa. Também carrega os registros necessários aos relacionamentos;
por exemplo, a proposta de uma votação selecionada. Cadastros e catálogos ficam completos.
A seleção usa uma ordem calculada por hash, para repetir a escolha com a mesma origem.
**O piloto serve para testar a carga, não para calcular indicadores da população.**

## O que conferir antes de usar a nova base

- O preflight deve terminar sem erros. Ele verifica campos obrigatórios, chaves,
  relações entre tabelas, competências, valores e compatibilidade com o destino.
- A reconciliação deve confirmar a mesma quantidade e o mesmo resumo do conteúdo
  na origem e no destino. Ela roda tanto no piloto como na carga completa.
- Confira o espaço de cada tabela, incluindo índices, e a medida **Disk** no painel
  do Supabase. Não basta multiplicar o tamanho do piloto para garantir que tudo caiba.
- Após `full`, execute as [consultas de validação de 2025](../../04_Analytics/consultas_validacao_2025.sql)
  e compare os resultados com a base anterior.

## Quando a carga encontra dados anteriores

Se a chave já existe e os campos mudaram, `ON CONFLICT DO UPDATE` atualiza o registro.
Se nada mudou, ele não é regravado. O exportador não apaga registros antigos.

Se o destino tiver uma chave que não existe na fonte, o preflight interrompe a
carga antes da escrita. Isso evita manter registros que ficaram fora do novo
conjunto. Confira a origem da diferença e prepare uma base separada para a recarga.
A regra também vale quando uma tabela da fonte está vazia.

## Se houver falha

O banco confirma a gravação a cada 5.000 registros. Uma falha interrompe a carga,
mas não desfaz os lotes já confirmados. Retome apenas com a mesma origem e depois
de corrigir a causa. A aplicação só deve usar a base quando a carga e sua conferência
estiverem completas.

Não reconstrua Silver ou Gold durante a exportação. O preflight usa memória do
driver para guardar as chaves de uma tabela por vez; a carga usa cursores para
ler os registros aos poucos.

O monitoramento consulta o tamanho do banco e do **WAL**, o registro de alterações
mantido pelo PostgreSQL. Essa soma não mede todo o disco físico. Os limites do
notebook são proteções locais; confira também o painel do Supabase.

Não publique senhas, tokens, scripts de cadastro de secrets ou saídas com
credenciais no GitHub.
