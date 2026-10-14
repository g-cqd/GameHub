"""Build bf4-recipe-candidate.json from the draft and run the repo validators on it.

Usage: python3 make_candidate.py <path to nfs-release/macos-app/Packaging>
Every value marked PLACEHOLDER below is a stand-in that lets the schema run; none is a measurement.
"""
import json, sys
from copy import deepcopy
from pathlib import Path
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
import recipes

here = Path(__file__).parent
draft = json.load(open(here / 'bf4-recipe-draft.json'))
cand = deepcopy(draft)
placeholders = []
rules = cand['importRules']
rules['machine'] = 'x86_64'
rules['rootFiles'] = ['bf4.exe', 'BFLauncher.exe', 'BF4WebHelper.exe']
for item in rules['directories']:
    if not isinstance(item['minimumBytes'], int):
        placeholders.append('importRules.directories[%s].minimumBytes (draft said TODO; set to 0)' % item['path'])
        item['minimumBytes'] = 0
if not any(d['path'] == '__Installer' for d in rules['directories']):
    rules['directories'].append({'path': '__Installer', 'minimumBytes': 0, 'excludedNames': [],
                                 'excludedSuffixes': ['.log', '.tmp'], 'excludedDirectories': []})
    placeholders.append('importRules.directories[__Installer] added so installerdata.xml is inside a copied directory')
for key in [k for k in rules if k.startswith('_')]:
    del rules[key]
for marker in rules['markers']:
    fixed = [p.rsplit('/', 1)[-1] for p in marker['patterns']]
    if fixed != marker['patterns']:
        marker['patterns'] = fixed
        placeholders.append('importRules.markers[%s]: marker patterns may not contain a slash, so the nested path is reduced to its file name' % marker['name'])
for build in rules.get('knownBuilds', []):
    build['name'] = '1.8.2.48475'
    build['executableSHA256'] = '9d9d1a3fca6ffd4c34a543b3fd7b049336ddbd43c0e6c5eee742e51431a6c2aa'
placeholders.append('importRules.knownBuilds: SHA-256 of bf4.exe_DiP_Staged read on the mbp23 skeleton; unconfirmed against a complete install')
rules['maximumFiles'] = 30000
rules['maximumBytes'] = 48_000_000_000
placeholders.append('importRules.maximumFiles=30000 and maximumBytes=48e9: placeholders at the Swift ceilings (30000 files, 64e9 bytes); measure on a complete install')
cand['supportsMP'] = False
placeholders.append('supportsMP set to false (draft said TODO)')
cand['storeClient']['offerID'] = ['1007968', '1011575', '1011576', '1011577', '1010268', '1010269',
    '1010270', '1010271', '1010958', '1010959', '1010960', '1010961', '1007077', '1016751', '1016757',
    '1016754', '1015365', '1015364', '1015363', '1015362']
placeholders.append('storeClient.offerID: the 20 manifest ids, corroborated but not yet confirmed against the owner activation log; DLC ids may need trimming')
cand['storeClient']['launchChain'] = ['BFLauncher.exe', 'BF4WebHelper.exe', 'bf4.exe']
cand['storeClient']['leaseTarget'] = 'bf4.exe'
cand['storeClient']['expectedPorts'] = [3215, 3216]
placeholders.append('storeClient.launchChain/leaseTarget/expectedPorts: from DESIGN.md, unconfirmed at runtime; 3216 unverified')
cand['_candidate'] = {'placeholders': placeholders, 'note': 'Not a shipped recipe. Unresolved draft TODOs remain elsewhere in this file.'}
json.dump(cand, open(here / 'bf4-recipe-candidate.json', 'w'), indent=1)

r = deepcopy(cand)
def strip(o):
    if isinstance(o, dict):
        return {k: strip(v) for k, v in o.items() if not k.startswith('_')}
    if isinstance(o, list):
        return [strip(v) for v in o]
    return o
r = strip(r)
for name, fn, arg in [('validate_import_rules', recipes.validate_import_rules, r['importRules']),
                      ('validate_store_client', recipes.validate_store_client, r['storeClient']),
                      ('validate_recipe', recipes.validate_recipe, r)]:
    try:
        fn(arg); print(name, 'OK')
    except Exception as e:
        print(name, 'REJECTS:', type(e).__name__, str(e)[:200])
