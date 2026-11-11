# Analytics — Análise de Dados

Responsável: Vitória

Esta pasta contém os códigos utilizados para geração de indicadores e análises a partir dos dados consolidados na camada Gold.

## Consultas para conferir os dados

`consultas_validacao_2025.sql` contém consultas somente de leitura para PostgreSQL:
separa fatos de 2025 do contexto histórico, expõe resultados desconhecidos,
meses sem registros e despesas sem vínculo cadastral. Execute após uma carga `full`
reconciliada; o piloto técnico não deve alimentar indicadores.

As definições, denominadores e limitações estão em
[Metodologia dos dados](../03_Gold/METODOLOGIA_DADOS.md). As sugestões de indicadores
abaixo são possibilidades de análise, não métricas já implementadas ou validadas.

## Entrada
- Dados da camada Gold

## Saída
- Indicadores e resultados analíticos utilizados pela aplicação e pelas visualizações

## Observação
Alterações podem ocorrer ao longo do projeto. Atualizar o readme conforme necessário.

# Sugestões para Analytics

A etapa de Analytics deve consumir os indicadores e agregações produzidos na camada Gold.

O objetivo é consultar, validar e explorar os indicadores definidos no projeto, preparando os dados que poderão ser disponibilizados pelo backend e posteriormente apresentados no frontend.

## Atividade parlamentar

- consultar o número de proposições apresentadas;
- comparar proposições por tipo e período;
- consultar o número de votações participadas;
- analisar taxa de participação e ausências, caso esses indicadores sejam considerados metodologicamente válidos.

## Comportamento em votações

- analisar percentuais de votos "Sim", "Não" e abstenções;
- comparar a distribuição dos votos entre partidos;
- comparar comportamento de voto entre parlamentares, partidos e UFs;
- analisar alinhamento partidário, caso o indicador seja implementado na Gold.

## Produção legislativa

- comparar o total de proposições entre parlamentares;
- comparar produção por partido e UF;
- analisar a evolução temporal da produção;
- consultar situação das proposições;
- analisar aprovação ou avanço das proposições, caso o indicador seja implementado.

## Despesas

- comparar despesas entre parlamentares;
- comparar despesas entre partidos e UFs;
- analisar despesas por categoria;
- analisar a evolução mensal dos gastos;
- identificar valores muito acima ou abaixo do padrão observado.

## Representação política

- analisar a distribuição dos parlamentares por partido;
- analisar a representação por UF;
- comparar a composição partidária das Casas;
- comparar Câmara e Senado.

## Indicadores estatísticos

- analisar média, mediana, mínimo e máximo;
- analisar desvio-padrão e percentis;
- analisar proporções e variações temporais;
- gerar rankings descritivos;
- investigar correlações entre variáveis quando houver sentido analítico.

## Saídas da etapa

A etapa pode produzir:

- consultas SQL/DQL;
- views ou consultas preparadas para consumo;
- tabelas de validação;
- análises exploratórias;
- documentação das regras de consulta;
- protótipos de visualização para validação dos indicadores, quando necessário.

As visualizações finais da aplicação devem ser implementadas no frontend, utilizando os dados disponibilizados pelo backend.

Os cálculos principais e as regras dos indicadores devem permanecer na camada Gold, evitando duplicação da lógica de negócio.

---

## Notas da camada Gold (atualizado em out/2026)

A camada Gold está implementada no schema `workspace.pi_ii_gold` com 26 tabelas normalizadas. As consultas de Analytics devem partir dessas tabelas.

### Tabelas principais para indicadores

| Indicador | Tabelas Gold relevantes |
|-----------|-------------------------|
| Atividade parlamentar | `proposicao`, `autoria`, `votacao`, `voto`, `votacao_proposicao` |
| Produção legislativa | `proposicao`, `tipo_proposicao`, `autoria`, `total_publicado`, `status_atual` |
| Comportamento em votações | `voto`, `tipo_voto`, `votacao`, `parlamentar`, `partido` |
| Despesas | `despesa`, `valor_despesa`, `tipo_despesa`, `fornecedor`, `parlamentar` |
| Representação política | `parlamentar`, `partido`, `uf`, `casa`, `cadastro_observado` |

### Tabelas com maior volume de dados

- `voto`: ~506 mil registros (votos individuais)
- `despesa` / `valor_despesa`: ~780 mil registros cada
- `autoria`: ~456 mil registros
- `proposicao`: ~264 mil registros

### Convenções importantes para consultas

- Todos os IDs são `STRING` (não usar como INT)
- `casa` ∈ {`'CAMARA'`, `'SENADO'`}
- `id_lote` identifica a tabela Silver de origem (proveniência)
- Chaves primárias costumam ser compostas (ex: `casa + id_parlamentar`, `casa + id_proposicao`)
- Para cruzar votações com proposições, usar a tabela `votacao_proposicao` como bridge
- Para valores de despesa, `despesa` traz o cabeçalho e `valor_despesa` traz os valores monetários (documento, glosa, líquido)
