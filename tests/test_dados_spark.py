"""Transformações reais com fixtures pequenas; requer PySpark e Java compatíveis."""

import csv
from decimal import Decimal
import importlib.util
from pathlib import Path
import re
import tempfile
import unittest

from test_dados import ROOT, SILVER, GOLD, EXPORT, carregar_funcoes, celulas


@unittest.skipUnless(importlib.util.find_spec('pyspark'), 'PySpark não disponível')
class TransformacoesSparkTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from pyspark.sql import SparkSession
        cls.warehouse = tempfile.TemporaryDirectory(prefix='pi_ii_spark_')
        cls.spark = (SparkSession.builder.master('local[1]').appName('PI-II-dados')
                     .config('spark.ui.enabled', 'false').config('spark.sql.shuffle.partitions', '1')
                     .config('spark.sql.warehouse.dir', Path(cls.warehouse.name).as_uri())
                     .getOrCreate())
        cls.spark.sparkContext.setLogLevel('ERROR')

    @classmethod
    def tearDownClass(cls):
        cls.spark.stop()
        cls.warehouse.cleanup()

    def contexto(self):
        from pyspark.sql import functions as F
        from pyspark.sql.window import Window
        return {'spark': self.spark, 'F': F, 'Window': Window,
                'col': F.col, 'trim': F.trim, 'upper': F.upper, 'to_date': F.to_date}

    def test_documento_com_varios_movimentos_preserva_todos_os_valores(self):
        contexto = self.contexto()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'despesas_2025.csv'
            registro = dict(ideDocumento='10', ideCadastro='000123', nuDeputadoId='42',
                            txNomeParlamentar='Nome de teste', sgUF='SP', sgPartido='TESTE',
                            numAno='2025', numMes='1', txtDescricao='Passagens',
                            txtFornecedor='Fornecedor', txtCNPJCPF='00123456000100',
                            datEmissao='2025-01-10', vlrDocumento='100.00', vlrGlosa='0.00',
                            vlrLiquido='100.00', numParcela='1')
            estorno = dict(registro, vlrDocumento='-20.00', vlrLiquido='-20.00', numParcela='2')
            with path.open('w', encoding='utf-8', newline='') as arquivo:
                writer = csv.DictWriter(arquivo, fieldnames=registro, delimiter=';')
                writer.writeheader()
                writer.writerows([registro, estorno, estorno])
            contexto['df_despesas_camara'] = (self.spark.read.option('header', 'true')
                .option('delimiter', ';').csv(str(path))
                .withColumn('uf_particao', contexto['F'].lit('sp'))
                .withColumn('ano_particao', contexto['F'].lit('2025'))
                .withColumn('_caminho', contexto['F'].lit(str(path))))
            contexto['gravar_silver'] = lambda *_: None
            source = next(source for source in celulas(SILVER) if 'df_movimentos = ' in source)
            exec(source, contexto)
            rows = contexto['df_despesas_camara_silver'].collect()
            self.assertEqual(len(rows), 3)
            self.assertEqual(len({row.id_movimento for row in rows}), 3)
            self.assertEqual({row.id_documento for row in rows}, {'10'})
            self.assertEqual({row.id_deputado_api for row in rows}, {'000123'})
            self.assertEqual({row.cnpj_cpf_fornecedor for row in rows}, {'00123456000100'})
            self.assertEqual(sum(row.valor_liquido for row in rows), Decimal('60.00'))
            ids_antes = {row.id_movimento for row in rows}
            contexto['df_despesas_camara'] = (contexto['df_despesas_camara']
                .withColumn('uf_particao', contexto['F'].lit('outra_pasta'))
                .withColumn('_caminho', contexto['F'].lit('/outro/caminho.csv')))
            exec(source, contexto)
            self.assertEqual(ids_antes, {row.id_movimento for row in contexto['df_despesas_camara_silver'].collect()})

    def test_fallback_com_cabecalho_minimo_nao_contamina_proposicoes(self):
        contexto = self.contexto()
        contexto['ler_entidade_por_uf'] = lambda *_: self.spark.sql("SELECT '1' AS id, 'Anual' AS ementa")
        contexto['BRONZE_CAMARA'] = 'fixture'
        with tempfile.TemporaryDirectory() as directory:
            vazio = Path(directory) / 'vazio.csv'
            vazio.write_text('_id_proposicao;_uf_recorte;_ano_arquivo_autores\n', encoding='utf-8')
            recuperado = Path(directory) / 'recuperado.csv'
            recuperado.write_text('id;ementa\n1;Não substituir\n2;Recuperada\n', encoding='utf-8')
            contexto['arquivos_entidade'] = lambda *_: [str(vazio), str(recuperado)]
            source = celulas(SILVER)[0]
            source = source[source.index('df_proposicoes = '):source.index('df_proposicoes_autores = ')]
            exec(source, contexto)
            self.assertEqual({row.id: row.ementa for row in contexto['df_proposicoes'].collect()}, {'1': 'Anual', '2': 'Recuperada'})

    def test_mesma_chave_com_conteudo_divergente_interrompe_antes_da_gravacao(self):
        contexto = carregar_funcoes(SILVER, {'gravar_silver'}, self.contexto())
        df = self.spark.sql("SELECT '1' AS id, 'A' AS valor UNION ALL SELECT '1', 'B'")
        with self.assertRaisesRegex(ValueError, 'conflitantes'):
            contexto['gravar_silver'](df, 'teste', ['id'])

    def test_aprovacao_desconhecida_nao_vira_rejeicao(self):
        source = next(source for source in celulas(GOLD) if '-- 18 VOTACAO' in source)
        casos = re.findall(r'CASE WHEN .*?END AS aprovacao', source, flags=re.S)
        self.assertEqual(len(casos), 2)
        camara = self.spark.sql(f"SELECT {casos[0]} FROM VALUES (1), (0), (NULL), (2) AS t(aprovacao)")
        self.assertEqual([row.aprovacao for row in camara.collect()], [True, False, None, None])
        senado = self.spark.sql(f"SELECT {casos[1]} FROM VALUES ('Aprovado'), ('Rejeitada'), (NULL), ('Não aprovado'), ('Retirado') AS t(resultado)")
        self.assertEqual([row.aprovacao for row in senado.collect()], [True, False, None, None, None])

    def test_piloto_preserva_casas_e_meses_disponiveis(self):
        contexto = carregar_funcoes(EXPORT, {'amostra_por_grupo'}, self.contexto())
        df = self.spark.sql("""
            SELECT casa, mes, CAST(id AS STRING) AS id_despesa
            FROM VALUES ('CAMARA'), ('SENADO') AS casas(casa)
            CROSS JOIN VALUES (1), (12) AS meses(mes)
            CROSS JOIN range(10)
        """)
        amostra = contexto['amostra_por_grupo'](df, ['casa', 'mes'], 'id_despesa', 5)
        grupos = {(row.casa, row.mes): row['count'] for row in amostra.groupBy('casa', 'mes').count().collect()}
        self.assertEqual(grupos, {('CAMARA', 1): 5, ('CAMARA', 12): 5, ('SENADO', 1): 5, ('SENADO', 12): 5})

    def test_consultas_separam_ano_cobertura_e_contexto(self):
        fixtures = {
            'casa': "SELECT 'CAMARA' AS casa UNION ALL SELECT 'SENADO'",
            'proposicao': """SELECT 'CAMARA' AS casa, DATE '2025-01-01' AS data_apresentacao, 2025 AS ano
                UNION ALL SELECT 'CAMARA', DATE '2024-01-01', 2024
                UNION ALL SELECT 'SENADO', CAST(NULL AS DATE), 2025""",
            'votacao': """SELECT 'CAMARA' AS casa, 'v1' AS id_votacao, DATE '2025-01-01' AS data_votacao,
                TRUE AS aprovacao, '1' AS resultado_original
                UNION ALL SELECT 'CAMARA', 'v2', DATE '2026-01-01', NULL, 'Desconhecido'""",
            'despesa': """SELECT 'CAMARA' AS casa, 'm1' AS id_despesa, 'd1' AS id_documento,
                '42' AS id_parlamentar, 2025 AS ano, 1 AS mes
                UNION ALL SELECT 'CAMARA', 'm2', 'd1', '99', 2025, 1""",
            'valor_despesa': """SELECT 'CAMARA' AS casa, 'm1' AS id_despesa,
                CAST(100 AS DECIMAL(12,2)) AS valor_liquido, CAST(NULL AS DECIMAL(12,2)) AS valor_restituicao
                UNION ALL SELECT 'CAMARA', 'm2', -20, NULL""",
            'identificador_parlamentar': "SELECT 'CAMARA' AS casa, 'CEAP' AS sistema, '42' AS codigo_externo, '000123' AS id_parlamentar",
            'parlamentar': "SELECT 'CAMARA' AS casa, '000123' AS id_parlamentar",
            'voto': "SELECT 'CAMARA' AS casa, 'v1' AS id_votacao, 'PARTIDO_DO_EVENTO' AS partido, 'SIM' AS codigo_voto",
        }
        for nome, query in fixtures.items():
            self.spark.sql(query).createOrReplaceTempView(nome)
        source = (ROOT / '04_Analytics/consultas_validacao_2025.sql').read_text(encoding='utf-8')
        source = re.sub(r'--[^\n]*', '', source).replace('public.', '')
        source = source.replace('generate_series(1, 12)', 'range(1, 13)')
        resultados = [self.spark.sql(query).collect() for query in source.split(';') if query.strip()]
        producao = {row.casa: row for row in resultados[0]}
        self.assertEqual(producao['CAMARA'].apresentadas_em_2025, 1)
        self.assertEqual(producao['SENADO'].ano_2025_sem_data, 1)
        self.assertEqual(resultados[1][0].votacoes_em_2025, 1)
        meses = {(row.casa, row.mes): row for row in resultados[3]}
        self.assertEqual(meses[('CAMARA', 1)].movimentos, 2)
        self.assertEqual(meses[('CAMARA', 1)].documentos, 1)
        self.assertEqual(meses[('CAMARA', 1)].total_liquido, Decimal('80.00'))
        self.assertIsNone(meses[('CAMARA', 12)].total_liquido)
        self.assertEqual(resultados[4][0].sem_vinculo, 1)
        self.assertEqual(resultados[4][0].valor_sem_vinculo, Decimal('-20.00'))
        self.assertEqual(resultados[5][0].partido, 'PARTIDO_DO_EVENTO')


if __name__ == '__main__':
    unittest.main()
