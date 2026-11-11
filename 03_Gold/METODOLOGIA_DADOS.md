# Como os dados são tratados e conferidos

Este guia explica as mudanças no tratamento dos dados e como conferir o resultado.
O período de análise continua sendo **janeiro a dezembro de 2025**.

## Por onde começar

O caminho dos dados é:

```text
APIs públicas → Bronze → Silver → Gold → PostgreSQL/Supabase → aplicação
```

A **Bronze** guarda os registros coletados. A **Silver** organiza os campos e
confere os registros. A **Gold** separa as informações em tabelas relacionadas.
O notebook de **exportação** leva essas tabelas ao banco usado pela aplicação.

Para acompanhar as mudanças no código, leia nesta ordem:

1. [Notebook Silver](../02_Silver/Silver%20Layer%20Transformations.ipynb): seleção
   dos arquivos, função `gravar_silver` e transformação das despesas da Câmara.
2. [Notebook Gold](LegisAnalytica%20-%20Gold%20Layer%20DDL.ipynb): identificação
   dos parlamentares, movimentos de despesa e resultados de votação.
3. [Guia da exportação](export/README.md): verificações antes e depois da carga.
4. [Consultas de validação](../04_Analytics/consultas_validacao_2025.sql): perguntas
   que ajudam a conferir os números carregados.

## O que mudou e por quê

| Antes | Agora | Motivo |
|---|---|---|
| Um padrão de nome podia misturar proposições e autores. | Cada entidade lê seus próprios arquivos anuais. | As colunas desses arquivos são diferentes. |
| A despesa era deduplicada pelo documento. | Os movimentos são preservados e o documento fica em um campo separado. | Um documento pode aparecer em vários registros válidos. |
| A despesa da Câmara era ligada ao deputado pelo nome. | O vínculo usa o identificador oficial `ideCadastro`. | Nomes podem mudar ou ter grafias diferentes. |
| Resultados desconhecidos de votação viravam `false`. | Continuam como `null`, com o resultado original preservado. | Não saber o resultado é diferente de saber que houve rejeição. |
| A carga ignorava alterações em registros já existentes. | Atualiza os campos alterados e confere o conteúdo ao final. | A fonte pode corrigir informações sem mudar o identificador. |

## Quais dados estamos analisando

A Bronze coleta registros de 2023 a 2026 para o grupo de parlamentares definido
pela **57ª legislatura**. Esse grupo também é chamado de *coorte* no projeto.
No Senado, os períodos de exercício ajudam a definir quem pertence ao grupo.

A exportação seleciona os registros de 2025. Também carrega registros de outros
anos quando eles são necessários para entender os relacionamentos. Por exemplo:
uma proposta apresentada em 2024 e votada em 2025 pode aparecer no banco, mas não
deve ser contada como uma proposta apresentada em 2025.

Há dois cuidados ao descrever os resultados:

- As proposições dependem das autorias coletadas para esse grupo. Não podemos
  chamar o conjunto de “todas as proposições do Congresso” sem conferir a cobertura.
- Selecionar um ano inteiro não comprova que a coleta está completa. Um mês sem
  registros pode significar ausência de fatos ou uma falha de coleta.

Não usamos sorteio para formar uma amostra estatística. A intenção é cobrir o
grupo definido no projeto; precisamos medir quanto dele foi de fato coletado.

## Como a Silver lê e confere os arquivos

Cada entidade lê apenas arquivos com o formato `entidade_YYYY.csv`, em que `YYYY`
é o ano. Assim, `proposicoes_2025.csv` não se mistura com
`proposicoes_autores_2025.csv`.

Os arquivos chamados de **fallback** guardam proposições recuperadas pela API
quando faltaram no arquivo anual. Eles são lidos separadamente e só acrescentam
IDs ausentes. Arquivos vazios podem ter menos colunas no cabeçalho.

Os campos entram como texto. Isso preserva identificadores como `000123`, que
virariam `123` se fossem lidos como números. Só depois convertemos datas, anos,
valores monetários e indicadores verdadeiro/falso para seus tipos correspondentes.

A gravação de uma entidade é interrompida se houver chave vazia ou registros com
a mesma chave e conteúdos diferentes. Cópias equivalentes, como a mesma proposição
em arquivos de duas UFs, podem ser reunidas em um único registro.

`uf_particao` informa a pasta de origem. Uma proposta com autores de várias UFs
pode ter cópias em várias pastas. Para contar autorias por UF, use a tabela
`autoria`; para analisar votos por UF, use a UF do próprio voto.

Ao concluir, a Silver grava em `auditoria_carga` as quantidades de entrada, saída
e cópias reunidas. Essa conferência não substitui as auditorias de coleta da Bronze.

## Documento e movimento de despesa são coisas diferentes

**Documento** é o comprovante. **Movimento** é cada registro relacionado à despesa.
A documentação da Câmara informa que `ideDocumento` pode aparecer em vários
registros. Por isso, não podemos escolher apenas uma linha por documento.

Exemplo de dados de teste:

| Documento | Movimento | Valor líquido |
|---|---|---:|
| 10 | 1 | R$ 100,00 |
| 10 | 2 | −R$ 20,00 |

Há **um documento, dois movimentos e R$ 80,00 de valor líquido**. Manter apenas
uma linha mudaria o total. Os registros negativos podem representar ajustes e
precisam ser interpretados conforme a fonte.

Na Câmara, os campos passam a ter estes papéis:

- `id_documento`: preserva o `ideDocumento` oficial e pode se repetir.
- `id_despesa`: identifica o movimento dentro do projeto. Usa um hash da linha
  e um número de ocorrência. O hash é um resumo calculado a partir do conteúdo.
- `valor_restituicao`: guarda separadamente a restituição informada pela fonte.
  A Silver também preserva parcela, ressarcimento, lote documental e data da restituição.

Mesmo duas linhas idênticas são preservadas: sem uma regra da fonte, não sabemos
se uma delas pode ser descartada. O número de ocorrência permite diferenciá-las.
Também não somamos automaticamente `valor_documento`, pois o valor de face do
comprovante pode se repetir nos movimentos.

O ID técnico segue `ceap:<SHA-256 da linha>:<ocorrência>`. Não é um identificador
oficial. Se o conteúdo ou as colunas da origem mudarem, ele pode mudar. A primeira
carga corrigida precisa de uma base separada para não misturar IDs antigos e novos.
No Senado, o ID da despesa fornecido pela fonte é mantido.

Para consultar o significado dos campos, leia a
[documentação oficial da CEAP](https://dadosabertos.camara.leg.br/howtouse/2023-12-26-dados-ceap.html).

## Como a despesa é ligada ao parlamentar

Na Câmara, `ideCadastro` é o ID usado pela API. `nuDeputadoId` é o código do
sistema de despesas CEAP. A tabela `identificador_parlamentar` relaciona os dois.
Esse relacionamento usa o identificador oficial, sem comparar nomes.

Se um código CEAP apontar para dois IDs de API, a transformação para e pede revisão.
Se o parlamentar não estiver no cadastro coletado, a despesa continua sem vínculo.
As consultas de validação mostram a quantidade e o valor desses casos.

## Como interpretar os indicadores

| Indicador | O que contar ou calcular |
|---|---|
| Produção de 2025 | Proposições com apresentação em 2025, contadas uma vez por `casa + id_proposicao`. Se só houver `ano=2025`, sem data, informar esses casos separadamente. |
| `total_publicado` | Proposições presentes no conjunto coletado por Casa e ano. A contagem não comprova cobertura completa da Casa. |
| Atividade de votação em 2025 | Votações realizadas em 2025, mesmo que a proposta seja de outro ano. |
| `tem_votacao` | Há uma votação vinculada na base, possivelmente de outro ano. `false` significa que não encontramos esse vínculo na base. |
| Aprovação | Resultado de uma votação específica. Não significa, por si só, aprovação final da proposta ou conversão em lei. |
| Despesa de 2025 | Movimento com competência financeira em 2025. A data de emissão do documento pode ser de outro período. |
| Quantidade de despesas | Quantidade de movimentos. Para contar documentos, usar `id_documento` sem repetições dentro de cada Casa. |
| Média mensal atual da API | Total líquido dividido pelos meses que têm registros de despesa. |

**Exemplo de média mensal:** R$ 12 mil registrados em três meses resultam em
R$ 4 mil por mês com registros. Dividir pelos 12 meses do ano daria R$ 1 mil.
São perguntas diferentes; a API mantém a primeira definição.

**Ausente não é zero.** Uma despesa de R$ 0,00 tem um valor conhecido. Um campo
`null` não tem valor informado. A listagem preserva essa diferença. Despesas sem
valor líquido conhecido impedem a exportação. Documento e glosa podem continuar
nulos, como ocorre em registros do Senado. O total líquido não desconta novamente
as restituições: elas ficam separadas até validarmos sua relação com o débito.

Na aprovação, `true` significa aprovação, `false` rejeição e `null` resultado
desconhecido. Na Câmara, só os códigos 1 e 0 são classificados. No Senado, só os
textos exatos `aprovado/aprovada` e `rejeitado/rejeitada`, ignorando maiúsculas e
espaços nas pontas. Outros textos ficam em `resultado_original` para revisão.

Partido e UF do voto são os informados no próprio registro. Usar o partido atual
do cadastro para classificar um voto antigo poderia atribuí-lo ao partido errado.
O partido informado nas despesas também tem limitações temporais descritas pela
fonte oficial. Comparações entre parlamentares devem considerar tempo de exercício
e cobertura dos dados; essas mudanças não criam rankings ou taxas de presença.

## Como conferir a carga

O **preflight** é a verificação feita antes de gravar no PostgreSQL. Ele confere:

- Campos obrigatórios e chaves que identificam os registros, chamadas de **PKs**.
- Relações entre tabelas, chamadas de **FKs**. Por exemplo, um voto precisa apontar
  para uma votação presente na carga.
- Competência, valores líquidos e estrutura das tabelas de destino.
- Registros do destino cujas chaves não estão mais na fonte. Eles impedem a carga
  para evitar misturar conjuntos diferentes, inclusive quando a fonte está vazia.

Se uma chave já existe e seus campos mudaram, a carga atualiza o registro. Ela não
apaga registros antigos. No final, a **reconciliação** compara origem e destino:
quantidade de registros, resumo do conteúdo de todos os campos e relações entre tabelas.
O resumo é chamado de *fingerprint* no código. Assim, duas tabelas com a mesma
quantidade de linhas, mas valores diferentes, não passam apenas pela contagem.

O banco confirma a gravação a cada lote de 5.000 registros, operação chamada de
**commit**. Se um lote falhar, os anteriores continuam gravados. Por isso, a aplicação
só deve usar a nova base depois de concluir a carga e a conferência.

### Primeira carga corrigida: ordem de execução

1. Guarde as contagens e os totais da base anterior para comparação.
2. Execute Silver e Gold em ordem. Confira `auditoria_carga` e os diagnósticos
   finais da Gold, incluindo resultados desconhecidos e vínculos ausentes.
3. Prepare uma base separada no PostgreSQL seguindo o
   [guia das migrations](supabase/migrations/README.md). Migration é um script que
   altera a estrutura do banco; sozinha, não recupera registros perdidos.
4. Execute `prepare`. Esse modo verifica os dados e o banco sem gravar nem criar tabelas.
5. Execute `pilot`. Ele carrega até cinco despesas por Casa/ano/mês disponível e
   cinco votações e proposições por Casa, acrescentando os registros relacionados
   necessários. Cadastros e catálogos ficam completos. É um teste de carga, não
   uma amostra para calcular indicadores.
6. Confira os dados, o tamanho das tabelas com índices e a medida **Disk** no painel
   do Supabase. O tamanho do piloto não garante que a carga completa caiba.
7. Execute `full` sobre o mesmo recorte e confira a reconciliação e as consultas
   de validação. Explique as diferenças em relação à base anterior.
8. Atualize o backend junto da estrutura do banco e só então aponte a aplicação
   para a base validada. Esses passos operacionais não são feitos automaticamente.

Não reconstrua Silver ou Gold enquanto a exportação estiver em andamento: a origem
precisa permanecer a mesma durante a comparação. Se a Silver falhar no meio, tabelas
anteriores podem já ter sido gravadas; conclua a execução antes de iniciar a Gold.

Em princípio, os CSVs da Bronze já guardam os campos oficiais necessários. Se eles
faltarem no acervo real, revise a coleta antes de continuar.

## Detalhes técnicos para manutenção

O lote da Gold registra a versão da tabela Delta usada para calcular seu hash.
Delta é o formato das tabelas usado no Databricks, com versões do conteúdo.
O SHA-256 considera a estrutura das colunas e os hashes de todas as linhas,
ordenados e incluindo repetições. Datas de coleta e cobertura permanecem nulas
quando não há metadado confirmado; a data de processamento não substitui a de coleta.

O fingerprint da exportação soma os hashes SHA-256 das linhas, mantendo o resultado
no intervalo de 256 bits. A soma permite comparar linhas em ordens diferentes e
ainda detectar mudanças na quantidade de repetições. Datas e decimais são colocados
no mesmo formato antes da comparação. Como todo resumo por hash, há possibilidade
teórica de colisão; isso não é uma assinatura digital.

O preflight guarda as chaves de uma tabela por vez na memória do computador que
coordena o Spark, chamado de **driver**. Volumes muito maiores podem exigir outra
forma de comparar as chaves. As tabelas completas não são guardadas nessa lista.

## Como executar os testes

Consulte o [guia dos testes](../tests/README.md) para comandos, pré-requisitos e
exemplos de resultado esperado. Os testes locais usam dados inventados, sem
credenciais. A validação da carga real no Databricks e no PostgreSQL continua necessária.
