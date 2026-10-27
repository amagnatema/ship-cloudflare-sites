import json
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'skills/ship-cloudflare-sites/scripts/audit-cloudflare-project.sh'
INSPECT = ROOT / 'skills/ship-cloudflare-sites/scripts/inspect-migrations.py'

class AuditTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)

    def config(self, value):
        (self.root / 'wrangler.jsonc').write_text(json.dumps(value))

    def inspect(self):
        return subprocess.check_output(['python3', str(INSPECT), str(self.root)], text=True).strip()

    def test_custom_d1_dirs_and_environment_bindings(self):
        self.config({'d1_databases': [{'migrations_dir': 'drizzle'}], 'env': {'production': {'d1_databases': [{'migrations_dir': 'sql/production'}]}}})
        for d in ['drizzle', 'sql/production']:
            path = self.root / d
            path.mkdir(parents=True)
            (path / '0000_initial.sql').write_text('SELECT 1;')
        self.assertEqual(self.inspect(), 'd1-migrations-found')
        (self.root / 'sql/production/0000_initial.sql').unlink()
        self.assertEqual(self.inspect(), 'd1-no-migrations')

    def test_no_d1_and_unparseable_are_not_reported_as_missing_migrations(self):
        self.config({'name': 'static'})
        self.assertEqual(self.inspect(), 'no-d1')
        (self.root / 'wrangler.jsonc').write_text('{broken')
        self.assertEqual(self.inspect(), 'unknown')

    def test_jsonc_comments_urls_and_trailing_commas(self):
        (self.root / 'wrangler.jsonc').write_text('{\n // comment\n "vars": {"URL": "https://example.com/path"},\n "d1_databases": [{"migrations_dir": "drizzle", /* trailing comment */}],\n}')
        (self.root / 'drizzle').mkdir()
        (self.root / 'drizzle/0001.sql').write_text('SELECT 1;')
        self.assertEqual(self.inspect(), 'd1-migrations-found')

    def test_audit_redacts_environment_and_script_values(self):
        self.config({'d1_databases': [{'migrations_dir': 'drizzle'}]})
        (self.root / 'drizzle').mkdir()
        (self.root / 'drizzle/0001.sql').write_text('SELECT 1;')
        sentinel = 'PRIVATE_TOKEN_VALUE_872364'
        (self.root / '.env').write_text('API_TOKEN='+sentinel+'\n')
        (self.root / '.dev.vars').write_text('WRANGLER_SECRET='+sentinel+'\n')
        (self.root / 'package.json').write_text(json.dumps({'scripts': {'deploy': 'wrangler deploy --var TOKEN:'+sentinel}}))
        out = subprocess.check_output(['bash', str(AUDIT), str(self.root)], text=True)
        self.assertNotIn(sentinel, out)
        self.assertIn('API_TOKEN=<redacted>', out)
        self.assertIn('migration_inspection: d1-migrations-found', out)
        self.assertNotIn('no ordered SQL migrations', out)

if __name__ == '__main__':
    unittest.main()
