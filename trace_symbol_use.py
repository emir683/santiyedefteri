import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]
defs_text = text[defs_idx:]

# Find which symbol in defs contains (106809.8, -259565.5) or Axis C
idx = defs_text.find('106809.8')
if idx != -1:
    g_start = defs_text.rfind('<g id="', 0, idx)
    g_end = defs_text.find('"', g_start + 7)
    sym_id = defs_text[g_start+7:g_end]
    print(f"Axis C/D is inside symbol: '{sym_id}'")

    # Now find where this symbol is used in ModelSpace!
    use_matches = list(re.finditer(rf'<use[^>]+xlink:href="#{sym_id}"[^>]*>', model_text))
    print(f"Used in ModelSpace {len(use_matches)} times:")
    for u in use_matches:
        print("  Use tag:", u.group(0))

    # Also check if it is used inside another symbol in defs (nested use)!
    nested_uses = list(re.finditer(rf'<use[^>]+xlink:href="#{sym_id}"[^>]*>', defs_text))
    print(f"Used inside other symbols {len(nested_uses)} times:")
    for nu in nested_uses:
        parent_g = defs_text.rfind('<g id="', 0, nu.start())
        parent_g_end = defs_text.find('"', parent_g + 7)
        parent_id = defs_text[parent_g+7:parent_g_end]
        print(f"  Parent symbol: '{parent_id}', tag: {nu.group(0)[:100]}")
