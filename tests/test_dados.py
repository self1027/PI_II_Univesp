"""Verificações locais do contrato de dados, sem Databricks ou credenciais."""

import ast
from contextlib import closing, redirect_stdout
from datetime import date, datetime
from decimal import Decimal
import hashlib
import io
import json
import re
from pathlib import Path
import sqlite3
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SILVER = ROOT / '02_Silver/Silver Layer Transformations.ipynb'
GOLD = ROOT / '03_Gold/LegisAnalytica - Gold Layer DDL.ipynb'
EXPORT = ROOT / '03_Gold/export/EXPORT_supabase_postgresql.ipynb'


def celulas(path):
    notebook = json.loads(path.read_text(encoding='utf-8'))
    return [''.join(cell.get('source', [])) for cell in notebook['cells']]


def carregar_funcoes(path, nomes, contexto=None):
    """Carrega só as funções escolhidas, sem executar a carga do notebook."""
    contexto = {} if contexto is None else contexto
    notebook = json.loads(path.read_text(encoding='utf-8'))
    for cell in notebook['cells']:
        if cell['cell_type'] != 'code':
            continue
        source = ''.join(cell.get('source', []))
        if source.lstrip().startswith(('%sql', '%pip')):
            continue
        for node in ast.walk(ast.parse(source)):
            if isinstance(node, ast.FunctionDef) and node.name in nomes:
                funcao_isolada = ast.Module(body=[node], type_ignores=[])
                codigo = compile(funcao_isolada, str(path), 'exec')
                exec(codigo, contexto)
    return contexto


class ContratoDadosTest(unittest.TestCase):
    def test_colunas_exportadas_existem_no_schema_inicial(self):
        source = next(source for source in celulas(EXPORT) if 'TABLES = [' in source)
        contexto = {}
        with redirect_stdout(io.StringIO()):
            exec(source, contexto)
        migration = (ROOT / '03_Gold/supabase/migrations/001_initial_schema_supabase.sql').read_text(encoding='utf-8')
        for tabela, colunas, _, _ in contexto['TABLES']:
            corpo = re.search(rf'CREATE TABLE public\.{tabela} \((.*?)\n\);', migration, re.S)[1]
            schema = set(re.findall(r'^\s+(\w+)\s+(?:TEXT|VARCHAR|CHAR|INTEGER|BIGINT|DATE|TIMESTAMP|BOOLEAN|NUMERIC)\b', corpo, re.M))
            self.assertEqual(set(colunas), schema, tabela)

    def test_selecao_nao_mistura_proposicoes_com_autores_ou_fallback(self):
        funcoes = carregar_funcoes(SILVER, {'arquivos_entidade'}, {'Path': Path})
        with tempfile.TemporaryDirectory() as directory:
            pasta = Path(directory) / 'sp'
            pasta.mkdir()
            for nome in ['proposicoes_2025.csv', 'proposicoes_autores_2025.csv',
                         'proposicoes_fallback_2025.csv', 'proposicoes_2025.csv.part']:
                (pasta / nome).touch()
            arquivos = funcoes['arquivos_entidade'](directory, 'proposicoes')
            self.assertEqual([Path(arquivo).name for arquivo in arquivos], ['proposicoes_2025.csv'])
            with self.assertRaises(FileNotFoundError):
                funcoes['arquivos_entidade'](directory, 'votos')

    def test_fingerprint_detecta_conteudo_e_multiplicidade_sem_depender_da_ordem(self):
        contexto = carregar_funcoes(EXPORT, {'valor_canonico', 'fingerprint_linhas'}, {
            'Decimal': Decimal, 'date': date, 'datetime': datetime,
            'json': json, 'hashlib': hashlib,
        })
        fingerprint = contexto['fingerprint_linhas']
        linhas = [('1', Decimal('10.00'), date(2025, 1, 1)), ('2', None, None)]
        self.assertEqual(fingerprint(linhas), fingerprint(reversed(linhas)))
        self.assertEqual(fingerprint(linhas[:1]), fingerprint([('1', Decimal('10.0'), '2025-01-01')]))
        self.assertNotEqual(fingerprint(linhas), fingerprint([('1', Decimal('11'), date(2025, 1, 1)), linhas[1]]))
        self.assertNotEqual(fingerprint(linhas), fingerprint(linhas + [linhas[0]]))
        self.assertNotEqual(fingerprint([('1', None)]), fingerprint([('1', Decimal('0'))]))
        self.assertEqual(fingerprint([('1', Decimal('-0.00'))]), fingerprint([('1', Decimal('0.00'))]))

    def test_upsert_corrige_conteudo_e_preserva_nulo(self):
        contexto = carregar_funcoes(EXPORT, {'build_insert_sql'})
        sql = contexto['build_insert_sql']('exemplo', ['casa', 'id', 'valor'], ['casa', 'id'])
        # SQLite permite testar o comportamento sem um servidor; ROW é sintaxe do PostgreSQL.
        sql = sql.replace('%s', '?').replace('ROW(', '(')
        with closing(sqlite3.connect(':memory:')) as conn:
            conn.execute("ATTACH DATABASE ':memory:' AS public")
            conn.execute('CREATE TABLE public.exemplo (casa TEXT, id TEXT, valor TEXT, PRIMARY KEY (casa, id))')
            conn.execute(sql, ('CAMARA', '1', '10'))
            conn.execute(sql, ('SENADO', '1', '20'))
            conn.execute(sql, ('CAMARA', '1', '11'))
            self.assertEqual(conn.execute("SELECT valor FROM public.exemplo WHERE casa='CAMARA'").fetchone(), ('11',))
            antes = conn.total_changes
            conn.execute(sql, ('CAMARA', '1', '11'))
            self.assertEqual(conn.total_changes, antes)
            conn.execute(sql, ('CAMARA', '1', None))
            self.assertEqual(conn.execute("SELECT valor FROM public.exemplo WHERE casa='CAMARA'").fetchone(), (None,))
            self.assertEqual(conn.execute("SELECT valor FROM public.exemplo WHERE casa='SENADO'").fetchone(), ('20',))

    def test_prepare_nao_chama_exportacao_ou_migration(self):
        source = next(source for source in celulas(EXPORT) if 'results = []' in source and 'export_table(' in source)

        def conexao_proibida():
            self.fail('prepare tentou abrir uma conexão para escrever')

        contexto = {'EXPORT_MODE': 'prepare', 'get_connection': conexao_proibida}
        exec(source, contexto)
        self.assertFalse(contexto['export_completed'])
        self.assertEqual(contexto['results'], [])
        for source in celulas(EXPORT):
            self.assertNotIn('cur.execute(migration_sql)', source)

    def test_notebooks_tem_sintaxe_valida_e_texto_utf8(self):
        for path in [SILVER, GOLD, EXPORT]:
            notebook = json.loads(path.read_text(encoding='utf-8'))
            for index, cell in enumerate(notebook['cells']):
                source = ''.join(cell.get('source', []))
                self.assertNotIn('\ufffd', source)
                for word in ['C?mara', 'n?o', 'execu??o', 'cabe?alho', 'conte?do']:
                    self.assertNotIn(word, source)
                self.assertIsNone(re.search(r'[A-Za-z]\?[A-Za-z?]', source))
                if cell['cell_type'] == 'code' and not source.lstrip().startswith(('%sql', '%pip')):
                    ast.parse(source, filename=f'{path}:cell{index}')


if __name__ == '__main__':
    unittest.main()
