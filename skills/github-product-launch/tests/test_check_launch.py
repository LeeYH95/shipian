import importlib.util
import json
import struct
import tempfile
import unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('check_launch',Path(__file__).parents[1]/'scripts/check_launch.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class AuditTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        (self.root/'README.md').write_text('![Hero](hero.png)',encoding='utf-8')
        (self.root/'feature.py').write_text('def export(): pass',encoding='utf-8')
        (self.root/'hero.png').write_bytes(b'\x89PNG\r\n\x1a\n'+b'\0'*8+struct.pack('>II',1600,900))
        self.data={'product':{'name':'Sample','summary':'Keep context'},'claims':[{'text':'Export','evidence':['feature.py']}],'assets':[{'path':'hero.png','role':'banner','origin':'composition','source':'README.md','rights':'project-owned','width':1600,'height':900}]}
    def tearDown(self): self.temp.cleanup()
    def run_audit(self):
        (self.root/'launch-manifest.json').write_text(json.dumps(self.data),encoding='utf-8')
        return module.audit(self.root,'launch-manifest.json')
    def test_valid(self): self.assertTrue(self.run_audit()['ok'])
    def test_missing_evidence(self):
        self.data['claims'][0]['evidence']=['missing.swift'];self.assertFalse(self.run_audit()['ok'])
    def test_wrong_dimensions(self):
        self.data['assets'][0]['width']=1280;self.assertFalse(self.run_audit()['ok'])
    def test_path_escape(self):
        self.data['assets'][0]['path']='../secret.png';self.assertIn('unsafe-path',[x['check'] for x in self.run_audit()['errors']])
    def test_external_symlink(self):
        (self.root/'external').symlink_to(Path(self.temp.name).parent,target_is_directory=True)
        self.assertIn('external-symlink',[x['check'] for x in self.run_audit()['errors']])
    def test_secret_report_does_not_repeat_secret(self):
        fake='ghp_'+'x'*36
        (self.root/'leak.txt').write_text(fake,encoding='utf-8')
        result=self.run_audit();self.assertFalse(result['ok']);self.assertNotIn(fake,json.dumps(result))
    def test_unknown_rights(self):
        self.data['assets'][0]['rights']='pending';self.assertFalse(self.run_audit()['ok'])
    def test_readme_broken_link(self):
        (self.root/'README.md').write_text('[Install](missing.md)',encoding='utf-8');self.assertFalse(self.run_audit()['ok'])

if __name__=='__main__':unittest.main()
