#!/usr/bin/env python3
"""Read-only launch audit. Writes only the optional explicit report path."""
import argparse
import json
import re
import struct
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

if sys.version_info < (3, 10):
    raise SystemExit('Python 3.10+ required')

TEXT_SUFFIXES = {'.md', '.txt', '.json', '.yml', '.yaml', '.py', '.swift', '.sh', '.html', '.js', '.mjs', '.css', '.toml', '.strings'}
SKIP = {'.git', '.build', 'build', 'node_modules', '.media', '.hyperframes', '__pycache__'}
PATTERNS = [
    ('private-key', re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),
    ('github-token', re.compile(r'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{35,}')),
    ('personal-path', re.compile('/' + r'Users/[^/\s]+/|C:\\Users\\[^\\\s]+\\')),
]

def audit(root, manifest):
    root = Path(root).resolve()
    errors = []
    def fail(kind, path):
        errors.append({'check': kind, 'path': str(path)})
    def local(value):
        candidate = root / value
        if Path(value).is_absolute() or not candidate.resolve().is_relative_to(root):
            fail('unsafe-path', value)
            return None
        if not candidate.is_file():
            fail('missing-file', value)
            return None
        return candidate
    mf = local(manifest)
    if mf is None:
        return {'ok': False, 'errors': errors}
    try:
        data = json.loads(mf.read_text(encoding='utf-8'))
    except (ValueError, UnicodeError):
        return {'ok': False, 'errors': [{'check':'invalid-manifest','path':manifest}]}
    product = data.get('product', {})
    if not product.get('name') or not product.get('summary'):
        fail('product-fields', manifest)
    claims, assets = data.get('claims', []), data.get('assets', [])
    if not claims: fail('claims-empty', manifest)
    for claim in claims:
        if not claim.get('text') or not claim.get('evidence'):
            fail('claim-evidence', manifest)
        for evidence in claim.get('evidence', []): local(evidence)
    if not assets: fail('assets-empty', manifest)
    for asset in assets:
        for field in ('path','role','origin','source','rights'):
            if not asset.get(field): fail('asset-'+field, asset.get('path',''))
        if asset.get('rights','').lower() in ('unknown','pending','待确认','未知'):
            fail('unresolved-rights', asset.get('path',''))
        source = asset.get('source','')
        if not urlsplit(source).scheme and source: local(source)
        path = local(asset.get('path',''))
        if path is None: continue
        if path.stat().st_size > data.get('max_asset_bytes',25000000): fail('asset-size',asset['path'])
        if path.suffix.lower() == '.png':
            with path.open('rb') as f: header=f.read(24)
            if len(header)<24 or header[:8] != b'\x89PNG\r\n\x1a\n':
                fail('invalid-png',asset['path'])
                continue
            width,height=struct.unpack('>II',header[16:24])
            if asset.get('width') != width or asset.get('height') != height: fail('png-dimensions',asset['path'])
    for name in data.get('readmes',['README.md']):
        path=local(name)
        if path is None: continue
        content=path.read_text(encoding='utf-8')
        for match in re.findall(r'\]\(<?([^\s)>]+)>?(?:\s+[^)]*)?\)|(?:src|srcset)="([^"]+)"',content):
            value=next(v for v in match if v)
            if urlsplit(value).scheme or value.startswith('#'): continue
            value=unquote(value.split('#',1)[0].split('?',1)[0])
            if value.startswith('../../'): continue  # hosting-relative Issues / Releases links
            local(str(path.parent.relative_to(root)/value))
    for path in sorted(root.rglob('*')):
        rel=path.relative_to(root)
        if any(part in SKIP for part in rel.parts): continue
        if path.is_symlink() and not path.resolve().is_relative_to(root):
            fail('external-symlink',rel)
            continue
        if not path.is_file(): continue
        if path.name in ('.env','credentials.json','id_rsa','id_ed25519') or (path.name.startswith('.env.') and path.name!='.env.example'):
            fail('credential-file',rel)
        if path.suffix not in TEXT_SUFFIXES or path.stat().st_size>2_000_000: continue
        try: text=path.read_text(encoding='utf-8')
        except UnicodeError: continue
        for label,pattern in PATTERNS:
            if pattern.search(text): fail(label,rel)
    return {'ok':not errors,'asset_count':len(assets),'claim_count':len(claims),'errors':errors,
            'limits':['Rule-based current-tree check; not a complete secret scan, license review, visual review or Git-history audit.']}

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--root',required=True)
    p.add_argument('--manifest',default='launch-manifest.json')
    p.add_argument('--report')
    a=p.parse_args()
    result=audit(a.root,a.manifest)
    encoded=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    if a.report:
        target=Path(a.report); target.parent.mkdir(parents=True,exist_ok=True)
        temp=target.with_name(target.name+'.tmp');temp.write_text(encoded,encoding='utf-8');temp.replace(target)
    print(encoded,end='')
    return 0 if result['ok'] else 1

if __name__=='__main__': sys.exit(main())
