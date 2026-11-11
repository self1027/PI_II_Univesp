# Backend

Responsável: João

Esta pasta contém o backend da aplicação e os endpoints utilizados para disponibilizar os dados e indicadores ao frontend.

Credenciais, tokens e outras informações sensíveis não devem ser versionados no GitHub.

## O que muda nos dados entregues pela API

Aplicar as migrations `002` e `003` junto desta versão do backend. A primeira carga
corrigida deve usar base separada, conforme a
[metodologia](../../03_Gold/METODOLOGIA_DADOS.md).

- `id_despesa` identifica um movimento. Na Câmara, o ID técnico muda em relação à
  carga antiga; `id_documento` preserva o documento original e pode se repetir.
- `valor_documento`, `valor_glosa`, `valor_liquido` e `valor_restituicao` preservam
  valores nulos na listagem. A exportação exige valor líquido conhecido.
- `Votacao.aprovacao` pode ser `true`, `false` ou `null`. `resultado_original`
  preserva o dado de origem. Isso não informa aprovação final de uma proposição.
- `Vote.partido` e `Vote.uf` são os valores informados no registro do voto.
- `tem_votacao=false` significa ausência de vínculo na base, não prova de que a
  proposição nunca foi votada.
- `media_mensal` continua sendo total dividido pelos meses com registros.
- Listas podem conter contexto de outros anos. Os indicadores anuais precisam dos
  filtros definidos na metodologia; as consultas existentes não viram filtros
  anuais implicitamente.

O frontend não foi alterado nesta etapa; seus textos sobre aprovação, contagem de
despesas e ausência de vínculos precisam considerar essas definições na próxima etapa.

## Fonte de dados
 
 O backend consome as tabelas da camada Gold no PostgreSQL.

### Convenções importantes

- Todos os IDs são `STRING` (não INT) — considerar na serialização JSON e nos tipos de resposta da API
- `casa` ∈ {`'CAMARA'`, `'SENADO'`} — pode ser usado como parâmetro de filtro nos endpoints
- Chaves primárias compostas são comuns (ex: `casa + id_parlamentar`, `casa + id_proposicao`)
- Para despesas, a tabela `despesa` traz o cabeçalho e `valor_despesa` traz os valores monetários; o JOIN é por `casa + id_despesa`
- Para votações, a tabela `votacao_proposicao` faz a ligação entre `votacao` e `proposicao`

### Tabelas mais relevantes para a API

| Endpoint provável | Tabelas Gold |
|------------------|--------------|
| Parlamentares | `parlamentar`, `cadastro_observado`, `parlamentar_legislatura` |
| Proposições | `proposicao`, `autoria`, `tipo_proposicao`, `status_atual` |
| Votações | `votacao`, `voto`, `tipo_voto`, `votacao_proposicao` |
| Despesas | `despesa`, `valor_despesa`, `tipo_despesa`, `fornecedor` |
| Filtros | `casa`, `uf`, `partido`, `legislatura` |

## Observação
Alterações podem ocorrer ao longo do projeto. Atualizar o readme conforme necessário.

# LegisAnalytica API
 
API para acompanhamento de dados legislativos, consumindo a camada Gold de dados.
 
## Como subir a aplicação
 
### Pré-requisitos
- Go 1.27.3 ou posterior, conforme `go.mod`
- Senha para acesso ao DB no supabase

### Instalação e Execução
1. Clone o repositório:
```bash
git clone <url-do-repositorio>
cd backend
```
2. Instale as dependências:
```bash
go mod tidy
```

3. Crie o .env e ajuste `DATABASE_URL` e `CORS_ALLOWED_ORIGIN`:
```bash
cp .env.example .env
```

Defina `CORS_ALLOWED_ORIGIN` com a origem do frontend (protocolo, domínio e porta, sem caminho ou barra final), por exemplo `http://localhost:3000`. Apenas essa origem será permitida no CORS, com método `POST` e cabeçalho `Content-Type`; o preflight `OPTIONS` é tratado automaticamente. Se a variável estiver vazia, requisições com `Origin` serão bloqueadas. Requisições sem `Origin`, como chamadas de servidor e curl, continuam funcionando. Reinicie a API após alterar o `.env`.

4. Execute a aplicação:
```bash
go run ./cmd/api
```

O servidor estará disponível em `http://localhost:8080/graphql`.

### Testes de integração

Para executar os testes de integração, basta rodar:

```bash
go test -v ./cmd/api
```
 
## 📖 Documentação da API
 
A API utiliza **GraphQL**, permitindo consultas flexíveis dos dados legislativos.

A especificação OpenAPI da API se encontra disponível no arquivo `api/openapi.yml`. Dessa forma, é possível utilizar o arquivo para validação da documentação da api através de ferramentas como https://www.openapiviewer.com. Um link gerado anteriormente para a documentação: https://www.openapiviewer.com/view/2026-11-03T02-20-28-543Z--110aba67db2118f5e398ccb5f25627498e42a51d58efa9d83b1d6c751aa930fe--openapi-yaml#?route=overview

### Helper para o frontend

Como o handler não lê `variables`, monte a query com `JSON.stringify` nos valores. Isso escapa as strings e evita quebrar ou injetar conteúdo na query.

```js
async function gql(query) {
  const res = await fetch("/graphql", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ query }),
  });
  if (!res.ok) throw new Error(await res.text()); // 400 e 405 vêm como texto
  const json = await res.json();
  if (json.errors) throw new Error(json.errors[0].message);
  return json.data;
}

const id = "5942";
const casa = "SENADO";
const data = await gql(`
  query {
    parlamentar(id: ${JSON.stringify(id)}, casa: ${JSON.stringify(casa)}) {
      nome_referencia
    }
  }
`);
```

## Referência rápida das consultas

| Consulta | Argumentos | Retorno |
|---|---|---|
| `parlamentar` | `id`!, `casa`! | `Politician` |
| `parlamentares` | `limit`=20, `offset`=0 | `[Politician]` |
| `buscaParlamentares` | `nome`!, `limit`=20, `offset`=0 | `[Politician]` |
| `casas` | - | `[House]` |
| `ufs` | - | `[State]` |
| `partidos` | - | `[Party]` |
| `legislaturas` | - | `[Legislature]` |
| `despesas` | `id`!, `limit`=20, `offset`=0, `type_code` | `[Expense]` |
| `atividade` | `id`!, `limit`=20, `offset`=0, `somente_votadas`=false | `[Proposition]` |
| `votos` | `id`!, `limit`=20, `offset`=0, `vote_code` | `[Vote]` |
| `todas_proposicoes` | `limit`=20, `offset`=0 | `[Proposition]` |
| `todos_votos` | `limit`=20, `offset`=0 | `[Vote]` |

`!` = obrigatório.

Campos aninhados:

- `Politician`: `estado`, `partido`, `legislaturas`, `despesas(limit, offset, type_code)`, `atividade(limit, offset)`, `votos(limit, offset, vote_code)`
- `Expense`: `tipo`, `fornecedor`
- `Vote`: `votacao`, `tipo`
- `Votacao`: `proposicoes`

## Paginação

Todas as listas usam `limit` e `offset`. Para a página `n` (começando em 0) com tamanho `L`, use `offset = n * L`. O padrão é `limit: 20, offset: 0`.

## Consultas comuns

### 1. Dados de referência (para popular filtros)

```graphql
query {
  casas { casa nome }
  ufs { uf nome }
  partidos { sigla }
  legislaturas { numero_legislatura inicio fim }
}
```

### 2. Listagem de parlamentares

```graphql
query {
  parlamentares(limit: 20, offset: 0) {
    casa
    id_parlamentar
    nome_referencia
    url_foto
    partido { sigla }
    estado { uf }
  }
}
```

### 3. Busca de parlamentares por nome

```graphql
query {
  buscaParlamentares(nome: "Silva", limit: 20, offset: 0) {
    casa
    id_parlamentar
    nome_referencia
    url_foto
    partido { sigla }
    estado { uf }
  }
}
```

### 4. Tudo de um parlamentar

```graphql
query {
  parlamentar(id: "5942", casa: "SENADO") {
    casa
    id_parlamentar
    nome_referencia
    url_foto
    email
    partido { sigla }
    estado { uf nome }
    legislaturas { numero_legislatura inicio fim }

    despesas(limit: 10) {
      id_despesa
      ano
      mes
      valor_liquido
      tipo { descricao }
      fornecedor { nome cnpj_cpf }
    }

    atividade(limit: 10) {
      id_proposicao
      sigla_tipo
      numero
      ano
      ementa
    }

    votos(limit: 10) {
      codigo_voto
      tipo { descricao }
      votacao {
        data_votacao
        descricao
        aprovacao
      }
    }
  }
}
```

> Esta query é pesada: cada item aninhado dispara chamadas extras ao serviço. Para telas de detalhe, prefira buscar cada seção separadamente (itens 5, 6 e 7) quando o usuário abrir a aba correspondente.

### 5. Despesas de um parlamentar

```graphql
query {
  parlamentar(id: "204554", casa: "CAMARA") {
    nome_referencia
    despesas(limit: 20, offset: 0) {
      id_despesa
      ano
      mes
      data_emissao
      valor_documento
      valor_glosa
      valor_liquido
      tipo { codigo_tipo descricao }
      fornecedor { nome cnpj_cpf }
    }
  }
}
```

Filtrar por tipo de despesa: `despesas(limit: 20, type_code: "1")`.

Atalho que só precisa do `id` (sem `casa`):

```graphql
query {
  despesas(id: "204554", limit: 20, offset: 0) {
    ano
    mes
    valor_liquido
    tipo { descricao }
    fornecedor { nome }
  }
}
```

### 6. Votações de um parlamentar

```graphql
query {
  parlamentar(id: "5942", casa: "SENADO") {
    nome_referencia
    votos(limit: 50, offset: 0) {
      id_votacao
      codigo_voto
      tipo { descricao }
      votacao {
        data_votacao
        sigla_orgao
        descricao
        aprovacao
        votos_sim
        votos_nao
        votos_outros
      }
    }
  }
}
```

Filtrar pelo tipo de voto: `votos(limit: 50, vote_code: "Sim")`.

Para ver a proposição de cada votação, adicione `proposicoes { sigla_tipo numero ano ementa }` dentro de `votacao`. O resultado depende de a ingestão popular a relação votação → proposição; se vier vazio, é provável que os dados não estejam carregados.

Atalho que só precisa do `id`:

```graphql
query {
  votos(id: "5942", limit: 100, offset: 0) {
    id_votacao
    codigo_voto
    tipo { descricao }
    votacao { data_votacao descricao aprovacao }
  }
}
```

### 7. Proposições de um parlamentar

> `atividade` retorna apenas proposições em que o parlamentar é o **autor principal**. Apoios e co-autorias não aparecem como autoria.
>
> Use `somente_votadas: true` para retornar apenas proposições com votação registrada. O campo `tem_votacao` indica se a proposta possui votação vinculada.

```graphql
query {
  parlamentar(id: "5942", casa: "SENADO") {
    atividade(limit: 20, offset: 0) {
      id_proposicao
      sigla_tipo
      numero
      ano
      ementa
      data_apresentacao
    }
  }
}
```

### 8. Todas as proposições e todos os votos (visão geral)

```graphql
query {
  todas_proposicoes(limit: 20, offset: 0) {
    casa
    id_proposicao
    sigla_tipo
    numero
    ano
    ementa
  }
}
```

```graphql
query {
  todos_votos(limit: 20, offset: 0) {
    casa
    id_votacao
    id_parlamentar
    codigo_voto
    tipo { descricao }
  }
}
```

### 9. Parlamentares por UF

**Ainda não há filtro por UF no backend.** `parlamentares` aceita apenas `limit` e `offset`, e `buscaParlamentares` filtra apenas por nome.

Alternativa atual: paginar `parlamentares` pedindo `estado { uf }` e filtrar no cliente.

```graphql
query {
  parlamentares(limit: 100, offset: 0) {
    id_parlamentar
    casa
    nome_referencia
    estado { uf }
  }
}
```

```js
const doSP = lista.filter((p) => p.estado?.uf === "SP");
```

Isso é ineficiente (cada item resolve `estado` com uma chamada e é preciso varrer todas as páginas). Quando o argumento `uf` for implementado, a consulta passa a ser:

```graphql
query {
  parlamentares(uf: "SP", limit: 50) {
    id_parlamentar
    nome_referencia
    partido { sigla }
  }
}
```

## Boas práticas

- **Peça só os campos necessários.** Cada campo aninhado (`tipo`, `votacao`, `estado`, `partido`, `fornecedor`...) faz chamadas adicionais ao serviço, por item da lista.
- **Use `limit` baixo** em listas com muitos campos aninhados.
- **Carregue seções sob demanda** na tela de detalhe do parlamentar (despesas, votos e atividade em abas).
- **Trate `null`.** Campos como `estado`, `partido`, `tipo`, `fornecedor` e `votacao` podem vir `null` quando não houver dado relacionado.
- **Aliases para repetir uma consulta** na mesma requisição:

```graphql
query {
  sim: votos(id: "5942", vote_code: "Sim", limit: 10) { id_votacao }
  nao: votos(id: "5942", vote_code: "Não", limit: 10) { id_votacao }
}
```

## Erros

| Situação | Status | Corpo |
|---|---|---|
| Método diferente de `POST` | 405 | `Method not allowed` (texto) |
| JSON inválido | 400 | `Invalid request body` (texto) |
| Profundidade > 10 | 400 | `Query depth exceeds maximum allowed limit` (texto) |
| Campo ou argumento inválido | 200 | JSON com `errors[].message` detalhado |
| Falha interna | 200 | JSON com `errors[].message` genérico |

