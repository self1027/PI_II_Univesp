-- Campos adicionais para preservar a origem dos movimentos e dos votos.
-- Adicionar campos não recupera os movimentos descartados pela carga antiga.
-- Para a primeira carga corrigida, use uma base separada; consulte README.md.
BEGIN;

ALTER TABLE public.despesa
    ADD COLUMN IF NOT EXISTS id_documento TEXT;

ALTER TABLE public.valor_despesa
    ADD COLUMN IF NOT EXISTS valor_restituicao NUMERIC(12,2);

ALTER TABLE public.votacao
    ADD COLUMN IF NOT EXISTS resultado_original TEXT;

ALTER TABLE public.voto
    ADD COLUMN IF NOT EXISTS partido TEXT,
    ADD COLUMN IF NOT EXISTS uf VARCHAR(2);

COMMENT ON COLUMN public.despesa.id_despesa IS
    'Identificador do movimento; na Câmara não equivale a ideDocumento.';
COMMENT ON COLUMN public.despesa.id_documento IS
    'Documento de origem, que pode ter vários movimentos.';
COMMENT ON COLUMN public.valor_despesa.valor_liquido IS
    'Débito informado pela fonte; restituições são preservadas separadamente.';
COMMENT ON COLUMN public.votacao.aprovacao IS
    'Resultado desta votação: TRUE, FALSE ou NULL quando desconhecido.';
COMMENT ON COLUMN public.voto.partido IS
    'Partido informado no registro do voto, sem substituição pelo cadastro atual.';

COMMIT;
