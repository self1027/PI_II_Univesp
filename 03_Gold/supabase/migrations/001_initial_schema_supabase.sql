-- ============================================================
-- LegisAnalytica v5 — Esquema Inicial PostgreSQL / Supabase
-- Migration: 001_initial_schema.sql
--
-- Projeto: PI II • Grupo 14 • Univesp
-- Origem:  26 tabelas Gold em workspace.pi_ii_gold (Databricks Unity Catalog)
-- Destino: PostgreSQL — Supabase (schema public)
--
-- Convenções:
--   • Tabelas criadas na ordem de dependência de FKs (topológica).
--   • PKs e FKs implementadas como constraints nomeadas.
--   • Colunas marcadas com ? no modelo lógico permanecem NULLABLE.
--   • despesa.codigo_tipo admite NULL (329 registros do Senado sem tipo).
--   • despesa.id_parlamentar NÃO tem FK para parlamentar (código CEAP,
--     não código API; resolução via identificador_parlamentar).
--   • identificador_parlamentar.id_parlamentar admite NULL (216 CEAPs
--     sem mapeamento API).
--   • FKs compostas usam MATCH SIMPLE (padrão PostgreSQL): se qualquer
--     coluna for NULL, a constraint é ignorada.
--
-- Mapeamento de tipos Databricks → PostgreSQL:
--   STRING    → VARCHAR(n) ou TEXT
--   INT       → INTEGER
--   LONG      → BIGINT
--   DATE      → DATE
--   TIMESTAMP → TIMESTAMP
--   BOOLEAN   → BOOLEAN
--   DECIMAL(12,2) → NUMERIC(12,2)
--
-- Executar no SQL Editor do Supabase (PostgreSQL), NÃO no Databricks Spark SQL.
-- Executar em schema public ainda sem essas tabelas.
-- Transação única: falhas de DDL fazem ROLLBACK da migração.
-- Reexecução sobre schema existente exige plano de migração, não DROP CASCADE indiscriminado.
-- Os VARCHAR de comprimento arbitrário para campos STRING foram substituídos
-- por TEXT, mantendo limites apenas nos domínios conhecidos casa, uf, sistema.
-- Este SQL cria estrutura; execução e carregamento ainda dependem da auditoria
-- dos dados para valores obrigatórios, FKs e tamanho de colunas numéricas.
-- ============================================================

-- ============================================================
-- DROP (descomentar para re-executar em banco existente)
-- ============================================================
-- DROP TABLE IF EXISTS public.voto                   CASCADE;
-- DROP TABLE IF EXISTS public.valor_despesa          CASCADE;
-- DROP TABLE IF EXISTS public.votacao_proposicao     CASCADE;
-- DROP TABLE IF EXISTS public.exercicio              CASCADE;
-- DROP TABLE IF EXISTS public.total_publicado        CASCADE;
-- DROP TABLE IF EXISTS public.despesa               CASCADE;
-- DROP TABLE IF EXISTS public.votacao               CASCADE;
-- DROP TABLE IF EXISTS public.status_atual          CASCADE;
-- DROP TABLE IF EXISTS public.autoria               CASCADE;
-- DROP TABLE IF EXISTS public.vinculo_mandato       CASCADE;
-- DROP TABLE IF EXISTS public.proposicao            CASCADE;
-- DROP TABLE IF EXISTS public.fornecedor            CASCADE;
-- DROP TABLE IF EXISTS public.mandato               CASCADE;
-- DROP TABLE IF EXISTS public.parlamentar_legislatura CASCADE;
-- DROP TABLE IF EXISTS public.cadastro_observado    CASCADE;
-- DROP TABLE IF EXISTS public.identificador_parlamentar CASCADE;
-- DROP TABLE IF EXISTS public.tipo_despesa          CASCADE;
-- DROP TABLE IF EXISTS public.tipo_voto             CASCADE;
-- DROP TABLE IF EXISTS public.parlamentar          CASCADE;
-- DROP TABLE IF EXISTS public.causa_afastamento     CASCADE;
-- DROP TABLE IF EXISTS public.tipo_proposicao       CASCADE;
-- DROP TABLE IF EXISTS public.partido               CASCADE;
-- DROP TABLE IF EXISTS public.legislatura           CASCADE;
-- DROP TABLE IF EXISTS public.uf                    CASCADE;
-- DROP TABLE IF EXISTS public.casa                  CASCADE;
-- DROP TABLE IF EXISTS public.lote                  CASCADE;


BEGIN;

-- ============================================================
-- NÍVEL 0 — Sem dependências (catálogos raiz)
-- ============================================================

-- 01 LOTE
CREATE TABLE public.lote (
    id_lote          TEXT  NOT NULL,
    entidade_fonte   TEXT  NOT NULL,
    localizador      TEXT NOT NULL,
    hash_sha256      CHAR(64)     NOT NULL,
    processado_em    TIMESTAMP    NOT NULL,
    coletado_em      TIMESTAMP,
    cobertura_inicio DATE,
    cobertura_fim    DATE,
    CONSTRAINT pk_lote PRIMARY KEY (id_lote),
    CONSTRAINT uq_lote_entidade UNIQUE (entidade_fonte),
    CONSTRAINT uq_lote_hash UNIQUE (hash_sha256)
);

-- 02 CASA
CREATE TABLE public.casa (
    casa VARCHAR(10) NOT NULL,
    nome TEXT NOT NULL,
    CONSTRAINT pk_casa PRIMARY KEY (casa)
);

-- 03 UF
CREATE TABLE public.uf (
    uf   VARCHAR(2) NOT NULL,
    nome TEXT NOT NULL,
    CONSTRAINT pk_uf PRIMARY KEY (uf)
);

-- 04 LEGISLATURA
CREATE TABLE public.legislatura (
    numero_legislatura INTEGER NOT NULL,
    inicio             DATE    NOT NULL,
    fim                DATE    NOT NULL,
    CONSTRAINT pk_legislatura PRIMARY KEY (numero_legislatura)
);

-- 05 PARTIDO
CREATE TABLE public.partido (
    sigla TEXT NOT NULL,
    CONSTRAINT pk_partido PRIMARY KEY (sigla)
);

-- 06 TIPO_PROPOSICAO
CREATE TABLE public.tipo_proposicao (
    sigla_tipo TEXT NOT NULL,
    descricao  TEXT,
    CONSTRAINT pk_tipo_proposicao PRIMARY KEY (sigla_tipo)
);


-- ============================================================
-- NÍVEL 1 — Dependem apenas de catálogos raiz
-- ============================================================

-- 07 CAUSA_AFASTAMENTO
CREATE TABLE public.causa_afastamento (
    casa         VARCHAR(10) NOT NULL,
    codigo_causa TEXT NOT NULL,
    descricao    TEXT NOT NULL,
    CONSTRAINT pk_causa_afastamento PRIMARY KEY (casa, codigo_causa),
    CONSTRAINT fk_causa_afastamento_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa)
);

-- 08 PARLAMENTAR
CREATE TABLE public.parlamentar (
    casa            VARCHAR(10)  NOT NULL,
    id_parlamentar  TEXT  NOT NULL,
    nome_referencia TEXT NOT NULL,
    url_foto        TEXT,
    email           TEXT,
    id_lote         TEXT  NOT NULL,
    CONSTRAINT pk_parlamentar PRIMARY KEY (casa, id_parlamentar),
    CONSTRAINT fk_parlamentar_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_parlamentar_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);

-- 09 TIPO_VOTO
CREATE TABLE public.tipo_voto (
    casa         VARCHAR(10) NOT NULL,
    codigo_voto  TEXT NOT NULL,
    descricao    TEXT,
    CONSTRAINT pk_tipo_voto PRIMARY KEY (casa, codigo_voto),
    CONSTRAINT fk_tipo_voto_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa)
);

-- 10 TIPO_DESPESA
CREATE TABLE public.tipo_despesa (
    casa         VARCHAR(10)  NOT NULL,
    codigo_tipo  TEXT NOT NULL,
    descricao    TEXT NOT NULL,
    CONSTRAINT pk_tipo_despesa PRIMARY KEY (casa, codigo_tipo),
    CONSTRAINT fk_tipo_despesa_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa)
);


-- ============================================================
-- NÍVEL 2 — Dependem de parlamentar, legislatura, lote, catálogos
-- ============================================================

-- 11 IDENTIFICADOR_PARLAMENTAR
-- id_parlamentar admite NULL (216 CEAPs sem mapeamento API)
CREATE TABLE public.identificador_parlamentar (
    casa            VARCHAR(10) NOT NULL,
    sistema         VARCHAR(10) NOT NULL,
    codigo_externo  TEXT NOT NULL,
    id_parlamentar  TEXT,
    CONSTRAINT pk_identificador_parlamentar PRIMARY KEY (casa, sistema, codigo_externo),
    CONSTRAINT fk_ident_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_ident_parlamentar FOREIGN KEY (casa, id_parlamentar)
        REFERENCES public.parlamentar (casa, id_parlamentar)
);

-- 12 CADASTRO_OBSERVADO
CREATE TABLE public.cadastro_observado (
    casa            VARCHAR(10) NOT NULL,
    id_parlamentar  TEXT NOT NULL,
    id_lote         TEXT NOT NULL,
    partido         TEXT,
    uf              VARCHAR(2),
    CONSTRAINT pk_cadastro_observado PRIMARY KEY (casa, id_parlamentar, id_lote),
    CONSTRAINT fk_cad_obs_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_cad_obs_parlamentar FOREIGN KEY (casa, id_parlamentar)
        REFERENCES public.parlamentar (casa, id_parlamentar),
    CONSTRAINT fk_cad_obs_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote),
    CONSTRAINT fk_cad_obs_partido FOREIGN KEY (partido)
        REFERENCES public.partido (sigla),
    CONSTRAINT fk_cad_obs_uf FOREIGN KEY (uf)
        REFERENCES public.uf (uf)
);

-- 13 PARLAMENTAR_LEGISLATURA
CREATE TABLE public.parlamentar_legislatura (
    casa                VARCHAR(10) NOT NULL,
    id_parlamentar      TEXT NOT NULL,
    numero_legislatura  INTEGER     NOT NULL,
    criterio_inclusao   TEXT NOT NULL,
    id_lote             TEXT NOT NULL,
    CONSTRAINT pk_parlamentar_legislatura PRIMARY KEY (casa, id_parlamentar, numero_legislatura),
    CONSTRAINT fk_parl_leg_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_parl_leg_parlamentar FOREIGN KEY (casa, id_parlamentar)
        REFERENCES public.parlamentar (casa, id_parlamentar),
    CONSTRAINT fk_parl_leg_legislatura FOREIGN KEY (numero_legislatura)
        REFERENCES public.legislatura (numero_legislatura),
    CONSTRAINT fk_parl_leg_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);

-- 14 MANDATO
CREATE TABLE public.mandato (
    casa        VARCHAR(10) NOT NULL,
    id_mandato  TEXT NOT NULL,
    uf          VARCHAR(2)  NOT NULL,
    id_lote     TEXT NOT NULL,
    CONSTRAINT pk_mandato PRIMARY KEY (casa, id_mandato),
    CONSTRAINT fk_mandato_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_mandato_uf FOREIGN KEY (uf)
        REFERENCES public.uf (uf),
    CONSTRAINT fk_mandato_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);

-- 15 FORNECEDOR
CREATE TABLE public.fornecedor (
    casa     VARCHAR(10)  NOT NULL,
    cnpj_cpf TEXT  NOT NULL,
    nome     TEXT NOT NULL,
    id_lote  TEXT  NOT NULL,
    CONSTRAINT pk_fornecedor PRIMARY KEY (casa, cnpj_cpf),
    CONSTRAINT fk_fornecedor_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_fornecedor_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);

-- 16 PROPOSICAO
CREATE TABLE public.proposicao (
    casa               VARCHAR(10)  NOT NULL,
    id_proposicao      TEXT  NOT NULL,
    sigla_tipo         TEXT  NOT NULL,
    numero             INTEGER,
    ano                INTEGER,
    ementa             TEXT,
    data_apresentacao  DATE,
    url_inteiro_teor   TEXT,
    id_lote            TEXT  NOT NULL,
    CONSTRAINT pk_proposicao PRIMARY KEY (casa, id_proposicao),
    CONSTRAINT fk_proposicao_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_proposicao_tipo FOREIGN KEY (sigla_tipo)
        REFERENCES public.tipo_proposicao (sigla_tipo),
    CONSTRAINT fk_proposicao_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);


-- ============================================================
-- NÍVEL 3 — Dependem de mandato, parlamentar, proposicao, votacao
-- ============================================================

-- 17 VINCULO_MANDATO
CREATE TABLE public.vinculo_mandato (
    casa            VARCHAR(10) NOT NULL,
    id_mandato      TEXT NOT NULL,
    id_parlamentar  TEXT NOT NULL,
    participacao    TEXT NOT NULL,
    id_lote         TEXT NOT NULL,
    CONSTRAINT pk_vinculo_mandato PRIMARY KEY (casa, id_mandato, id_parlamentar),
    CONSTRAINT fk_vinc_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_vinc_mandato FOREIGN KEY (casa, id_mandato)
        REFERENCES public.mandato (casa, id_mandato),
    CONSTRAINT fk_vinc_parlamentar FOREIGN KEY (casa, id_parlamentar)
        REFERENCES public.parlamentar (casa, id_parlamentar),
    CONSTRAINT fk_vinc_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);

-- 18 AUTORIA
CREATE TABLE public.autoria (
    casa             VARCHAR(10)  NOT NULL,
    id_proposicao    TEXT  NOT NULL,
    id_autor         TEXT  NOT NULL,
    nome_autor       TEXT,
    partido          TEXT,
    uf               VARCHAR(2),
    ordem_assinatura INTEGER,
    principal        BOOLEAN      NOT NULL DEFAULT false,
    id_lote          TEXT  NOT NULL,
    CONSTRAINT pk_autoria PRIMARY KEY (casa, id_proposicao, id_autor),
    CONSTRAINT fk_autoria_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_autoria_proposicao FOREIGN KEY (casa, id_proposicao)
        REFERENCES public.proposicao (casa, id_proposicao),
    CONSTRAINT fk_autoria_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote),
    CONSTRAINT fk_autoria_partido FOREIGN KEY (partido)
        REFERENCES public.partido (sigla),
    CONSTRAINT fk_autoria_uf FOREIGN KEY (uf)
        REFERENCES public.uf (uf)
);

-- 19 STATUS_ATUAL
CREATE TABLE public.status_atual (
    casa                 VARCHAR(10)  NOT NULL,
    id_proposicao        TEXT  NOT NULL,
    data_hora            TIMESTAMP,
    sigla_orgao          TEXT,
    descricao_tramitacao TEXT,
    descricao_situacao   TEXT,
    apreciacao           TEXT,
    id_lote              TEXT  NOT NULL,
    CONSTRAINT pk_status_atual PRIMARY KEY (casa, id_proposicao),
    CONSTRAINT fk_status_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_status_proposicao FOREIGN KEY (casa, id_proposicao)
        REFERENCES public.proposicao (casa, id_proposicao),
    CONSTRAINT fk_status_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);

-- 20 VOTACAO
CREATE TABLE public.votacao (
    casa         VARCHAR(10) NOT NULL,
    id_votacao   TEXT NOT NULL,
    data_votacao DATE,
    sigla_orgao  TEXT,
    aprovacao    BOOLEAN,
    resultado_original TEXT,
    descricao    TEXT,
    votos_sim    INTEGER,
    votos_nao    INTEGER,
    votos_outros INTEGER,
    id_lote      TEXT NOT NULL,
    CONSTRAINT pk_votacao PRIMARY KEY (casa, id_votacao),
    CONSTRAINT fk_votacao_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_votacao_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);

-- 21 DESPESA
-- codigo_tipo admite NULL (329 registros do Senado)
-- cnpj_cpf admite NULL (107.958 registros)
-- id_parlamentar NÃO tem FK para parlamentar (código CEAP, não API)
CREATE TABLE public.despesa (
    casa            VARCHAR(10)  NOT NULL,
    id_despesa      TEXT  NOT NULL,
    id_documento    TEXT,
    id_parlamentar  TEXT,
    ano             INTEGER     NOT NULL,
    mes             INTEGER     NOT NULL,
    data_emissao    DATE,
    codigo_tipo     TEXT,
    cnpj_cpf        TEXT,
    id_lote         TEXT  NOT NULL,
    CONSTRAINT pk_despesa PRIMARY KEY (casa, id_despesa),
    CONSTRAINT fk_despesa_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_despesa_tipo_despesa FOREIGN KEY (casa, codigo_tipo)
        REFERENCES public.tipo_despesa (casa, codigo_tipo),
    CONSTRAINT fk_despesa_fornecedor FOREIGN KEY (casa, cnpj_cpf)
        REFERENCES public.fornecedor (casa, cnpj_cpf),
    CONSTRAINT fk_despesa_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);

-- 22 TOTAL_PUBLICADO
CREATE TABLE public.total_publicado (
    casa               VARCHAR(10) NOT NULL,
    ano                INTEGER     NOT NULL,
    total_proposicoes  BIGINT      NOT NULL,
    id_lote            TEXT NOT NULL,
    CONSTRAINT pk_total_publicado PRIMARY KEY (casa, ano),
    CONSTRAINT fk_total_pub_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_total_pub_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);


-- ============================================================
-- NÍVEL 4 — Dependem de vinculo_mandato, votacao, despesa
-- ============================================================

-- 23 EXERCICIO
-- FK composta (casa, id_mandato, id_parlamentar) → vinculo_mandato
-- codigo_causa admite NULL (82 registros)
CREATE TABLE public.exercicio (
    casa            VARCHAR(10) NOT NULL,
    id_exercicio    TEXT NOT NULL,
    id_mandato      TEXT NOT NULL,
    id_parlamentar  TEXT NOT NULL,
    inicio          DATE        NOT NULL,
    fim             DATE,
    codigo_causa    TEXT,
    id_lote         TEXT NOT NULL,
    CONSTRAINT pk_exercicio PRIMARY KEY (casa, id_exercicio),
    CONSTRAINT fk_exercicio_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_exercicio_vinculo FOREIGN KEY (casa, id_mandato, id_parlamentar)
        REFERENCES public.vinculo_mandato (casa, id_mandato, id_parlamentar),
    CONSTRAINT fk_exercicio_causa FOREIGN KEY (casa, codigo_causa)
        REFERENCES public.causa_afastamento (casa, codigo_causa),
    CONSTRAINT fk_exercicio_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);

-- 24 VOTACAO_PROPOSICAO
CREATE TABLE public.votacao_proposicao (
    casa           VARCHAR(10) NOT NULL,
    id_votacao     TEXT NOT NULL,
    id_proposicao  TEXT NOT NULL,
    id_lote        TEXT NOT NULL,
    CONSTRAINT pk_votacao_proposicao PRIMARY KEY (casa, id_votacao, id_proposicao),
    CONSTRAINT fk_vot_prop_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_vot_prop_votacao FOREIGN KEY (casa, id_votacao)
        REFERENCES public.votacao (casa, id_votacao),
    CONSTRAINT fk_vot_prop_proposicao FOREIGN KEY (casa, id_proposicao)
        REFERENCES public.proposicao (casa, id_proposicao),
    CONSTRAINT fk_vot_prop_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);

-- 25 VALOR_DESPESA
CREATE TABLE public.valor_despesa (
    casa            VARCHAR(10)    NOT NULL,
    id_despesa      TEXT    NOT NULL,
    valor_documento NUMERIC(12,2),
    valor_glosa     NUMERIC(12,2),
    valor_liquido   NUMERIC(12,2),
    valor_restituicao NUMERIC(12,2),
    id_lote         TEXT    NOT NULL,
    CONSTRAINT pk_valor_despesa PRIMARY KEY (casa, id_despesa),
    CONSTRAINT fk_valor_desp_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_valor_desp_despesa FOREIGN KEY (casa, id_despesa)
        REFERENCES public.despesa (casa, id_despesa),
    CONSTRAINT fk_valor_desp_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);


-- ============================================================
-- NÍVEL 5 — Depende de votacao, parlamentar, tipo_voto
-- ============================================================

-- 26 VOTO
-- codigo_voto admite NULL (887 registros)
CREATE TABLE public.voto (
    casa            VARCHAR(10) NOT NULL,
    id_votacao      TEXT NOT NULL,
    id_parlamentar  TEXT NOT NULL,
    codigo_voto     TEXT,
    partido         TEXT,
    uf              VARCHAR(2),
    id_lote         TEXT NOT NULL,
    CONSTRAINT pk_voto PRIMARY KEY (casa, id_votacao, id_parlamentar),
    CONSTRAINT fk_voto_casa FOREIGN KEY (casa)
        REFERENCES public.casa (casa),
    CONSTRAINT fk_voto_votacao FOREIGN KEY (casa, id_votacao)
        REFERENCES public.votacao (casa, id_votacao),
    CONSTRAINT fk_voto_parlamentar FOREIGN KEY (casa, id_parlamentar)
        REFERENCES public.parlamentar (casa, id_parlamentar),
    CONSTRAINT fk_voto_tipo_voto FOREIGN KEY (casa, codigo_voto)
        REFERENCES public.tipo_voto (casa, codigo_voto),
    CONSTRAINT fk_voto_lote FOREIGN KEY (id_lote)
        REFERENCES public.lote (id_lote)
);


-- ============================================================
-- ÍNDICES EM COLUNAS DE FK NÃO COBERTAS PELA PK
-- ============================================================

-- Índices em id_lote (FK para lote; id_lote nunca é PK)
CREATE INDEX idx_parlamentar_lote          ON public.parlamentar          (id_lote);
CREATE INDEX idx_cad_obs_lote              ON public.cadastro_observado   (id_lote);
CREATE INDEX idx_parl_leg_lote              ON public.parlamentar_legislatura (id_lote);
CREATE INDEX idx_mandato_lote               ON public.mandato              (id_lote);
CREATE INDEX idx_fornecedor_lote            ON public.fornecedor           (id_lote);
CREATE INDEX idx_proposicao_lote            ON public.proposicao           (id_lote);
CREATE INDEX idx_vinc_mandato_lote          ON public.vinculo_mandato      (id_lote);
CREATE INDEX idx_autoria_lote               ON public.autoria              (id_lote);
CREATE INDEX idx_status_atual_lote          ON public.status_atual         (id_lote);
CREATE INDEX idx_votacao_lote               ON public.votacao              (id_lote);
CREATE INDEX idx_despesa_lote               ON public.despesa              (id_lote);
CREATE INDEX idx_total_publicado_lote       ON public.total_publicado      (id_lote);
CREATE INDEX idx_exercicio_lote             ON public.exercicio            (id_lote);
CREATE INDEX idx_vot_prop_lote              ON public.votacao_proposicao   (id_lote);
CREATE INDEX idx_valor_desp_lote            ON public.valor_despesa       (id_lote);
CREATE INDEX idx_voto_lote                  ON public.voto                 (id_lote);

-- Índices em FKs compostas não cobertas pelo prefixo da PK
CREATE INDEX idx_ident_parlamentar         ON public.identificador_parlamentar (casa, id_parlamentar);
CREATE INDEX idx_cad_obs_parlamentar        ON public.cadastro_observado        (casa, id_parlamentar);
CREATE INDEX idx_parl_leg_legislatura       ON public.parlamentar_legislatura   (numero_legislatura);
CREATE INDEX idx_vinc_parlamentar           ON public.vinculo_mandato           (casa, id_parlamentar);
CREATE INDEX idx_autoria_partido            ON public.autoria                   (partido);
CREATE INDEX idx_autoria_uf                 ON public.autoria                   (uf);
CREATE INDEX idx_proposicao_sigla_tipo      ON public.proposicao                (sigla_tipo);
CREATE INDEX idx_despesa_codigo_tipo        ON public.despesa                   (casa, codigo_tipo);
CREATE INDEX idx_despesa_cnpj_cpf          ON public.despesa                   (casa, cnpj_cpf);
CREATE INDEX idx_exercicio_vinculo         ON public.exercicio                 (casa, id_mandato, id_parlamentar);
CREATE INDEX idx_exercicio_causa           ON public.exercicio                 (casa, codigo_causa);
CREATE INDEX idx_vot_prop_proposicao        ON public.votacao_proposicao        (casa, id_proposicao);
CREATE INDEX idx_voto_parlamentar           ON public.voto                      (casa, id_parlamentar);
CREATE INDEX idx_voto_tipo_voto            ON public.voto                      (casa, codigo_voto);


-- ============================================================
-- COMENTÁRIOS DE TABELA
-- ============================================================

COMMENT ON TABLE public.lote                       IS 'Lote de proveniência — um por entidade Silver de origem';
COMMENT ON TABLE public.casa                      IS 'Catálogo de casas legislativas (CAMARA, SENADO)';
COMMENT ON TABLE public.uf                        IS 'Catálogo de unidades federativas (27 UFs)';
COMMENT ON TABLE public.legislatura               IS 'Período de uma legislatura';
COMMENT ON TABLE public.partido                   IS 'Catálogo de siglas de partido observadas';
COMMENT ON TABLE public.tipo_proposicao            IS 'Catálogo de tipos de proposição/matéria';
COMMENT ON TABLE public.causa_afastamento          IS 'Causa de afastamento do exercício (Senado)';
COMMENT ON TABLE public.parlamentar               IS 'Cadastro de parlamentar por casa';
COMMENT ON TABLE public.identificador_parlamentar IS 'Código externo (API/CEAP) mapeado a parlamentar';
COMMENT ON TABLE public.cadastro_observado        IS 'Fotografia de parlamentar por lote (partido/uf)';
COMMENT ON TABLE public.parlamentar_legislatura   IS 'Parlamentar membro de uma legislatura';
COMMENT ON TABLE public.mandato                   IS 'Cadeira de mandato identificada (Senado)';
COMMENT ON TABLE public.vinculo_mandato           IS 'Pessoa ocupante de um mandato (Senado)';
COMMENT ON TABLE public.exercicio                 IS 'Intervalo de exercício de um vínculo de mandato';
COMMENT ON TABLE public.proposicao                IS 'Matéria/proposição legislativa';
COMMENT ON TABLE public.autoria                   IS 'Autor de uma proposição';
COMMENT ON TABLE public.status_atual              IS 'Situação de tramitação atual (Câmara)';
COMMENT ON TABLE public.votacao                   IS 'Votação de um órgão';
COMMENT ON TABLE public.votacao_proposicao        IS 'Ligação votação ↔ proposição';
COMMENT ON TABLE public.tipo_voto                 IS 'Catálogo de tipos de voto por casa';
COMMENT ON TABLE public.voto                      IS 'Voto individual de parlamentar em votação';
COMMENT ON TABLE public.total_publicado           IS 'Total de proposições publicadas por ano';
COMMENT ON TABLE public.tipo_despesa              IS 'Catálogo de tipos de despesa por casa';
COMMENT ON TABLE public.fornecedor                IS 'Fornecedor de despesa (CNPJ/CPF)';
COMMENT ON TABLE public.despesa                   IS 'Registro de despesa parlamentar';
COMMENT ON TABLE public.valor_despesa             IS 'Valores monetários da despesa';

-- ============================================================
-- FIM DO SCRIPT
-- 26 tabelas criadas em ordem topológica de dependência de FKs
-- ============================================================

COMMIT;
