# Projeto Integrador II - Univesp

Projeto desenvolvido na disciplina Projeto Integrador II do curso de Ciência de Dados da Univesp.

O projeto tem como objetivo desenvolver um sistema web para coletar, integrar, armazenar, analisar e visualizar dados político-legislativos brasileiros provenientes de fontes públicas, como a Câmara dos Deputados, o Senado Federal e o TSE.

A proposta busca reunir em uma única solução informações atualmente distribuídas entre diferentes portais e APIs, permitindo consultas integradas, indicadores, análises e visualizações sobre parlamentares, despesas, proposições, votações, votos individuais e partidos.

## Arquitetura geral

APIs públicas  
↓  
Bronze — coleta e armazenamento dos dados brutos  
↓  
Silver — limpeza, padronização e transformação  
↓  
Gold — modelagem e disponibilização dos dados consolidados  
↓  
Dados disponíveis para consumo

A partir da camada Gold, o desenvolvimento se divide em frentes complementares:

- Analytics — indicadores e análises de dados
- Backend — API e lógica da aplicação
- Frontend — interface web em JavaScript
- Visualização e acessibilidade — gráficos, dashboard e recursos de acessibilidade

## Estrutura do repositório

- `01_Bronze/` — coleta e ingestão dos dados
- `02_Silver/` — limpeza, padronização e transformação
- `03_Gold/` — modelagem relacional (26 tabelas), consultas SQL e estruturas consolidadas
- `04_Analytics/` — indicadores e análises de dados
- `05_Aplicacao/`
  - `backend/` — API e lógica da aplicação
  - `frontend/` — interface web, visualizações e acessibilidade

## Tecnologias e recursos

As regras do recorte de 2025, granularidade, cobertura, indicadores e recarga estão
documentadas em [Metodologia dos dados](03_Gold/METODOLOGIA_DADOS.md).
Antes de contribuir com consultas ou transformações, consulte essas definições.

- Databricks
- Computação em nuvem
- Python
- SQL
- Git e GitHub
- APIs REST
- JavaScript
- Banco de dados / arquitetura Lakehouse
- Visualização de dados
- Recursos de acessibilidade
- Testes e validação

## Equipe

- **Luana Inada Souza Santos** — Coleta de dados e camada Bronze
- **Rafael Sandrigo Rabal** — ETL, qualidade dos dados e camada Silver
- **Bruce Wellington Amorin da Silva** — Modelagem, SQL, camada Gold e integração do projeto
- **Vitória de Caires Siqueira** — Indicadores e análise de dados
- **João Marcelo da Silva Gomes** — Backend e API
- **Brenda Oliveira de Matos** — Frontend e JavaScript
- **Éder da Silva Almeida** — Visualização e acessibilidade
