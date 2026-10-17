"""Check actual APK entries, without loading missing resources from the source tree."""
from pathlib import Path
import argparse,json,re,zipfile

def inspect(apk, project):
    manifest=json.loads((project/'tools/mobile_export_resources.json').read_text(encoding='utf-8'))
    required=set(manifest['export_resources'])
    required.update(manifest.get('required_startup_scenes',[]))
    for uri in tuple(required):
        source=project/uri.removeprefix('res://')
        if source.suffix in {'.gd','.tscn','.tres'}:
            text=source.read_text(encoding='utf-8')
            required.update(re.findall(r'preload\(\s*[\"\'](res://[^\"\']+)[\"\']\s*\)',text))
            required.update(re.findall(r'\[ext_resource[^\]\n]*\bpath="(res://[^"]+)"',text))
    failures=[]
    with zipfile.ZipFile(apk) as archive:
        names=set(archive.namelist())
        def resolve(uri, visited=None):
            visited=set() if visited is None else visited
            if uri in visited:return False
            visited.add(uri)
            name='assets/'+uri.removeprefix('res://')
            if name in names:return True
            for suffix in ['.remap','.import']:
                sidecar=name+suffix
                if sidecar not in names:continue
                cfg=archive.read(sidecar).decode('utf-8')
                destinations=re.findall(r'^path(?:\.[^=]+)?="(res://[^"]+)"',cfg,re.M)
                if any(resolve(target,visited) for target in destinations):return True
            return False
        for uri in sorted(required):
            if not resolve(uri):failures.append('Missing APK resource: '+uri)
        damaged=archive.testzip()
        if damaged:failures.append('ZIP CRC failed: '+damaged)
        forbidden=[name for name in names if name.startswith(('assets/.docs/','assets/tools/','assets/tests/'))]
        failures.extend('Development entry exported: '+name for name in forbidden)
    return {'apk':str(apk),'bytes':apk.stat().st_size,'resources_checked':len(required),'failures':failures}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk',type=Path)
    parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    result=inspect(args.apk,args.project)
    if args.output:args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('APK_RESOURCES checks=%d failures=%d bytes=%d'%(result['resources_checked'],len(result['failures']),result['bytes']))
    for failure in result['failures']:print(failure)
    raise SystemExit(bool(result['failures']))
