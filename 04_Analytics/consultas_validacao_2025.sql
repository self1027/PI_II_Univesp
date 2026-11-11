-- PostgreSQL/Supabase. Somente leitura; executar após a carga full validada.
-- O piloto não deve ser usado para calcular os indicadores abaixo.

-- Não misturar apresentação em 2025 com proposições antigas carregadas por vínculo.
SELECT casa,
       COUNT(*) FILTER (WHERE data_apresentacao >= DATE '2025-01-01'
                          AND data_apresentacao < DATE '2026-01-01') AS apresentadas_em_2025,
       COUNT(*) FILTER (WHERE data_apresentacao IS NULL AND ano = 2025) AS ano_2025_sem_data,
       COUNT(*) AS proposicoes_no_destino
FROM public.proposicao
GROUP BY casa;

-- Uma votação posterior compõe contexto, sem entrar na atividade anual de 2025.
SELECT casa,
       COUNT(*) FILTER (WHERE data_votacao >= DATE '2025-01-01'
                          AND data_votacao < DATE '2026-01-01') AS votacoes_em_2025,
       COUNT(*) FILTER (WHERE aprovacao IS NULL) AS resultado_desconhecido,
       COUNT(*) AS votacoes_no_destino
FROM public.votacao
GROUP BY casa;

-- Revisar os textos desconhecidos antes de ampliar qualquer classificação.
SELECT casa, resultado_original, COUNT(*) AS quantidade
FROM public.votacao
WHERE aprovacao IS NULL
GROUP BY casa, resultado_original
ORDER BY casa, quantidade DESC;

-- Calendário completo expõe meses sem registros; ausência não vira gasto zero.
WITH calendario AS (
    SELECT casa, mes
    FROM public.casa
    CROSS JOIN generate_series(1, 12) AS meses(mes)
)
SELECT c.casa, c.mes, COUNT(d.id_despesa) AS movimentos,
       COUNT(DISTINCT d.id_documento) AS documentos,
       SUM(v.valor_liquido) AS total_liquido,
       SUM(v.valor_restituicao) AS restituicoes_informadas,
       COUNT(d.id_despesa) FILTER (WHERE v.valor_liquido IS NULL) AS valores_ausentes
FROM calendario c
LEFT JOIN public.despesa d ON d.casa = c.casa AND d.ano = 2025 AND d.mes = c.mes
LEFT JOIN public.valor_despesa v ON v.casa = d.casa AND v.id_despesa = d.id_despesa
GROUP BY c.casa, c.mes
ORDER BY c.casa, c.mes;

-- A cobertura do vínculo deve ser medida também em reais, não só em linhas.
WITH vinculos AS (
    SELECT d.*, p.id_parlamentar AS parlamentar_vinculado
    FROM public.despesa d
    LEFT JOIN public.identificador_parlamentar i
      ON d.casa = 'CAMARA' AND i.casa = d.casa
     AND i.sistema = 'CEAP' AND i.codigo_externo = d.id_parlamentar
    LEFT JOIN public.parlamentar p
      ON p.casa = d.casa
     AND p.id_parlamentar = CASE WHEN d.casa = 'CAMARA' THEN i.id_parlamentar ELSE d.id_parlamentar END
    WHERE d.ano = 2025
)
SELECT d.casa, COUNT(*) AS movimentos,
       COUNT(*) FILTER (WHERE d.parlamentar_vinculado IS NULL) AS sem_vinculo,
       SUM(v.valor_liquido) AS total_liquido,
       SUM(v.valor_liquido) FILTER (WHERE d.parlamentar_vinculado IS NULL) AS valor_sem_vinculo
FROM vinculos d
JOIN public.valor_despesa v ON v.casa = d.casa AND v.id_despesa = d.id_despesa
GROUP BY d.casa;

-- O partido vem do voto, sem atribuição retroativa do partido cadastral atual.
SELECT v.casa, v.partido, v.codigo_voto, COUNT(*) AS votos_registrados
FROM public.voto v
JOIN public.votacao t ON t.casa = v.casa AND t.id_votacao = v.id_votacao
WHERE t.data_votacao >= DATE '2025-01-01' AND t.data_votacao < DATE '2026-01-01'
GROUP BY v.casa, v.partido, v.codigo_voto;
