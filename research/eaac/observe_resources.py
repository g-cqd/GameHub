"""Observe one isolated service startup with bounded existing Wine resource traces."""
import argparse
import hashlib
import json
import os
import selectors
import signal
import subprocess
import time
from pathlib import Path
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--mode', choices=['service', 'installer'], default='service')
mode = parser.parse_args().mode
root = Path('/Volumes/ExT2/GameHub/work/eaac-current-install-20261015')
runtime = Path('/Volumes/ExT2/GameHub/work/codex-eaac-context/runtime')
archive = Path('/Users/gc/eaac-archive/eaac-acquisition-20261015')
log_path = archive / ('resource-observation-' + mode + '-20261016.log')
summary_path = archive / ('resource-observation-' + mode + '-20261016.json')
env = dict(os.environ, HOME=str(root/'home'), TMPDIR=str(root/'tmp'),
    WINEPREFIX=str(root/'prefix'), WINEMSYNC='1',
    WINEDLLOVERRIDES='winemenubuilder.exe=d', WINEDEBUG='-all,+resource,+msgbox,+loaddll')
env.pop('WINE_EAAC_RESEARCH_STOP', None)
start = time.monotonic()
target = [r'C:\Program Files\EA\AC\EAAntiCheat.GameService.exe'] if mode == 'service' else [r'C:\Inputs\EAAntiCheat.Installer.exe', '--install', '--title', 'f12024']
process = subprocess.Popen([str(runtime/'bin/wine'), *target],
    cwd=root/'prefix/drive_c/Program Files/EA/AC',env=env,
    stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True)
reason='deadline'; total=0; recent=b''; cleanup_error=None
try:
    with selectors.DefaultSelector() as selector, log_path.open('wb') as log:
        os.chmod(log_path,0o600)
        selector.register(process.stdout,selectors.EVENT_READ)
        deadline=start+30
        while time.monotonic()<deadline:
            if not selector.select(max(0,deadline-time.monotonic())):
                break
            chunk=os.read(process.stdout.fileno(),65536)
            if not chunk:
                reason='target-exited'; break
            if total+len(chunk)>16*1024*1024:
                reason='output-limit'; break
            log.write(chunk);total+=len(chunk);recent=(recent+chunk)[-4096:]
            if b'MSGBOX_OnInit' in recent and b'E111000D' in recent:
                reason='observed-known-fatal'; break
finally:
    if process.poll() is None:
        try:
            os.killpg(process.pid,signal.SIGKILL)
        except ProcessLookupError:
            pass
        except PermissionError as error:
            cleanup_error=str(error)
            if process.poll() is None:
                try:
                    process.kill()
                except (ProcessLookupError, PermissionError) as fallback_error:
                    cleanup_error += '; direct kill: ' + str(fallback_error)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        cleanup_error=(cleanup_error or '') + '; owned target did not exit within cleanup bound'
lines=log_path.read_text(errors='replace').splitlines()
resource_lines=[(i,l) for i,l in enumerate(lines,1) if ':resource:' in l]
summary={'mode':mode,'target_arguments':target,'pid':process.pid,'seconds':round(time.monotonic()-start,3),
    'stop_reason':reason,'target_returncode':process.returncode,
    'cleanup_error':cleanup_error,'external_stop_is_success':False,'log':str(log_path),'bytes':total,
    'sha256':hashlib.sha256(log_path.read_bytes()).hexdigest(),
    'resource_event_count':len(resource_lines),
    'opaque_id_events':[{'line':i,'text':l} for i,l in resource_lines
        if any(v in l.lower() for v in ['#2774','#27a6','10100','10150'])],
    'coverage':'Wine resource API tracing before endpoint; custom resource parsers and later paths excluded.'}
summary_path.write_text(json.dumps(summary,indent=2)+'\n');os.chmod(summary_path,0o600)
print(json.dumps(summary,indent=2))
if cleanup_error or reason in ['deadline','output-limit'] or not resource_lines:
    raise SystemExit(2)
