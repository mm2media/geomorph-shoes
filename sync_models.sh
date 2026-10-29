#!/usr/bin/env bash
# Sync per-concept GLBs into models/ and regenerate models/map.json (panel slug -> GLB path).
# Sources: /workspace/tpu_shoe/export/web/models.json ({"Concept Name": "file.glb", ...}),
# plus any *.glb under /workspace/tpu_shoe/export and /workspace named after a concept.
# Usage: ./sync_models.sh [--push]
set -euo pipefail
cd "$(dirname "$0")"
python3 - <<'PY'
import json,os,re,shutil,glob
slug=lambda s:re.sub(r'[^a-z0-9]+','-',s.lower().replace('_','-')).strip('-')
html=open('index.html').read()
panels=re.findall(r"^\['([a-z0-9-]+)','([^']+)'",html,re.M)
concept={}  # concept slug -> panel slugs
for p,name in panels:
    c='hex-slipon' if re.match(r'hex-(slipon|colorways)',p) else p
    concept.setdefault(c,[]).append(p)
alias={'hex-slip-on':'hex-slipon','hex-slip-on-inverted':'hex-slipon'}
found={'hex-slipon':'models/hex_slipon.glb'} if os.path.exists('models/hex_slipon.glb') else {}
def add(name,src):
    c=alias.get(slug(name),slug(name))
    if c not in concept or not os.path.exists(src): return
    dst='models/'+('hex_slipon.glb' if c=='hex-slipon' else c+'.glb')
    if os.path.abspath(src)!=os.path.abspath(dst): shutil.copy2(src,dst)
    found[c]=dst; print('model:',c,'<-',src)
for g in glob.glob('/workspace/tpu_shoe/export/**/*.glb',recursive=True)+glob.glob('/workspace/*.glb')+glob.glob('/workspace/*/*.glb'):
    if '/geomorph-shoes/' in g: continue
    add(os.path.splitext(os.path.basename(g))[0],g)
mj='/workspace/tpu_shoe/export/web/models.json'
if os.path.exists(mj):
    for name,f in json.load(open(mj)).items():
        f=f if isinstance(f,str) else f.get('file') or f.get('glb') or f.get('path')
        add(name,f if os.path.isabs(f) else os.path.join(os.path.dirname(mj),f))
out={p:found[c] for c,ps in concept.items() if c in found for p in ps}
json.dump(out,open('models/map.json','w'),indent=1)
print(len(out),'panels have models:',sorted(set(out.values())))
PY
if [ "${1:-}" = "--push" ]; then
  git add models && git commit -m "Sync 3D models" && git push
fi
