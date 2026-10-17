import subprocess
import re

res = subprocess.run(["rsvg-convert", "-f", "svg", "/home/ubuntu/cad-service/test_snippet.svg"], stdout=subprocess.PIPE, text=True)
for p in re.findall(r'<path[^>]+>', res.stdout):
    d = re.search(r'd="([^"]+)"', p)
    tr = re.search(r'transform="([^"]+)"', p)
    st = re.search(r'stroke="([^"]+)"', p)
    print(f"Path stroke={st.group(1) if st else 'none'} tr={tr.group(1) if tr else 'none'} d={d.group(1)[:60] if d else 'none'}")

