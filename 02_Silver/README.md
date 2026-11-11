# Silver — Qualidade e Transformação

Responsável: Rafael

Esta pasta contém os códigos de limpeza, padronização e transformação dos dados provenientes da camada Bronze.

## Notebook

- **Silver Layer Transformations** — lê os dados CSV da camada Bronze (volumes `workspace.pi_ii_bronze`), aplica padronização e tipos, e grava 13 tabelas no schema `workspace.pi_ii_silver`.

## Entrada
- Dados CSV da camada Bronze (`/Volumes/workspace/pi_ii_bronze/camara` e `/Volumes/workspace/pi_ii_bronze/senado`)

## Saída
- 13 tabelas tratadas e padronizadas no schema `workspace.pi_ii_silver`:

| Origem | Tabelas Silver |
|--------|----------------|
| Câmara | `deputados`, `proposicoes`, `proposicoes_autores`, `votacoes_camara`, `votos_camara`, `despesas_camara` |
| Senado | `senadores`, `senadores_exercicios`, `materias`, `materias_autorias`, `votacoes_senado`, `votos_senado`, `despesas_senado` |

As tabelas incluem `uf_particao` para rastreabilidade; arquivos anuais também
registram `ano_particao`. Essas colunas não substituem as dimensões dos fatos.

## Observação
Alterações podem ocorrer ao longo do projeto. Atualizar o readme conforme necessário.

## Regras de leitura e validação

- IDs são lidos como texto. Assim, um identificador `000123` não perde os zeros à esquerda.
- Cada entidade lê somente seus arquivos `entidade_YYYY.csv`; o fallback de
  proposições, que contém dados recuperados pela API, é lido separadamente e só acrescenta IDs ausentes.
- Cópias com os mesmos dados, distribuídas por UF, podem virar um único registro.
  Se a mesma chave tiver conteúdos diferentes, a gravação para e pede revisão.
  Chaves vazias também impedem a gravação.
- Despesas da Câmara preservam **todos os movimentos**, inclusive repetições
  idênticas. `ideDocumento` não é uma chave de movimento.
- `ideCadastro` é preservado para mapear o código CEAP ao parlamentar sem usar nomes.
- `auditoria_carga` registra contagens de entrada, saída e cópias reunidas
  após a execução completa. Não substitui as auditorias de cobertura da Bronze.

Execute as células em ordem. Uma falha pode deixar entidades anteriores já
gravadas; só execute a Gold depois da conclusão bem-sucedida da Silver.
As regras, limitações e o procedimento de recarga estão em
[Metodologia dos dados](../03_Gold/METODOLOGIA_DADOS.md).
