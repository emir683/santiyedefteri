with open('/home/ubuntu/cad-service/server.js', 'r', encoding='utf-8') as f:
    code = f.read()

old_block = """      // WebGL CAD verisini arka planda asenkron üret (mevcut PDF akışına hiç dokunmadan)
      const jsonFilename = `${fileId}_cad_data.json`;
      const jsonPath = path.join(UPLOAD_DIR, jsonFilename);
      exec(`python3 /home/ubuntu/cad-service/generate_full_cad_webgl.py "${svgPath}" "${jsonPath}"`, (pyErr) => {
        if (pyErr) console.error('[WEBGL GEN ERROR]', pyErr);
        else console.log(`[WEBGL SUCCESS] CAD JSON olusturuldu: ${jsonFilename}`);
      });"""

new_block = """      // WebGL CAD verisini arka planda asenkron üret (mevcut PDF akışına hiç dokunmadan - DXF ezdxf motoru)
      const jsonFilename = `${fileId}_cad_data.json`;
      const jsonPath = path.join(UPLOAD_DIR, jsonFilename);
      const dxfFilename = `${fileId}.dxf`;
      const dxfPath = path.join(UPLOAD_DIR, dxfFilename);
      exec(`dwg2dxf "${inputPath}" -o "${dxfPath}" && python3 /home/ubuntu/cad-service/dxf_pipeline.py "${dxfPath}" "${jsonPath}"`, (dxfErr) => {
        if (dxfErr) console.error('[WEBGL DXF ERROR]', dxfErr);
        else console.log(`[WEBGL SUCCESS] CAD JSON olusturuldu (DXF): ${jsonFilename}`);
      });"""

if old_block in code:
    code = code.replace(old_block, new_block)
    with open('/home/ubuntu/cad-service/server.js', 'w', encoding='utf-8') as f:
        f.write(code)
    print("SUCCESSFULLY PATCHED SERVER.JS!")
else:
    print("OLD BLOCK NOT FOUND, CHECKING ALTERNATIVE MATCH...")
    # Find generate_full_cad_webgl and replace
    import re
    if 'generate_full_cad_webgl.py' in code:
        code = re.sub(
            r'exec\(`python3 /home/ubuntu/cad-service/generate_full_cad_webgl\.py "[^"]+" "[^"]+"`,\s*\(pyErr\)\s*=>\s*\{[^}]+\}\);',
            r'''const dxfFilename = `${fileId}.dxf`;
      const dxfPath = path.join(UPLOAD_DIR, dxfFilename);
      exec(`dwg2dxf "${inputPath}" -o "${dxfPath}" && python3 /home/ubuntu/cad-service/dxf_pipeline.py "${dxfPath}" "${jsonPath}"`, (dxfErr) => {
        if (dxfErr) console.error('[WEBGL DXF ERROR]', dxfErr);
        else console.log(`[WEBGL SUCCESS] CAD JSON olusturuldu (DXF): ${jsonFilename}`);
      });''',
            code
        )
        with open('/home/ubuntu/cad-service/server.js', 'w', encoding='utf-8') as f:
            f.write(code)
        print("REPLACED VIA REGEX!")
    else:
        print("COULD NOT FIND TARGET")
