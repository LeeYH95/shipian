#!/usr/bin/env python3
"""Launch the actual app via LaunchServices; fail if its UI loop cannot report ready."""
import argparse, json, pathlib, subprocess, sys, time
p = argparse.ArgumentParser()
p.add_argument('--app', required=True)
p.add_argument('--data-dir')
p.add_argument('--normal', action='store_true')
p.add_argument('--report', required=True)
p.add_argument('--timeout', type=float, default=8)
a = p.parse_args()
report = pathlib.Path(a.report).resolve()
if report.exists():
    raise SystemExit('Use a fresh report path for each run')
args = ['open', '-n', str(pathlib.Path(a.app).resolve()), '--args']
if not a.normal: args += ['--demo']
if a.data_dir: args += ['--data-dir', str(pathlib.Path(a.data_dir).resolve())]
args += ['--startup-report', str(report)]
started = time.monotonic()
subprocess.run(args, check=True)
record = {}
while time.monotonic() - started < a.timeout:
    try:
        record = json.loads(report.read_text())
        if any(e['phase'] == 'ui-responsive' for e in record['events']):
            print(json.dumps({'result':'PASS','wall_seconds':round(time.monotonic()-started,3),**record}, ensure_ascii=False))
            sys.exit(0)
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    time.sleep(.1)
print(json.dumps({'result':'FAIL','wall_seconds':round(time.monotonic()-started,3),**record},ensure_ascii=False))
sys.exit(1)
