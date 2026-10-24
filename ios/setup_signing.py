#!/usr/bin/env python3
import base64
import os
import plistlib
import shutil
import subprocess
import sys

def main():
    runner_temp = os.environ.get('RUNNER_TEMP', '/tmp')
    cert_path = os.path.join(runner_temp, 'build_certificate.p12')
    pp_path = os.path.join(runner_temp, 'build_pp.mobileprovision')

    cert_b64 = os.environ.get('BUILD_CERTIFICATE_BASE64', '').strip()
    pp_b64 = os.environ.get('BUILD_PROVISION_PROFILE_BASE64', '').strip()
    p12_pass = os.environ.get('P12_PASSWORD', '').strip()

    if not cert_b64:
        sys.exit("HATA: 'BUILD_CERTIFICATE_BASE64' secret bulunamadi veya bos!")
    if not pp_b64:
        sys.exit("HATA: 'BUILD_PROVISION_PROFILE_BASE64' secret bulunamadi veya bos!")
    if not p12_pass:
        sys.exit("HATA: 'P12_PASSWORD' secret bulunamadi veya bos!")

    # 1. Base64 çöz ve kaydet
    with open(cert_path, 'wb') as f:
        f.write(base64.b64decode(cert_b64))
    print(f"✅ Sertifika cozumlendi: {cert_path}")

    with open(pp_path, 'wb') as f:
        f.write(base64.b64decode(pp_b64))
    print(f"✅ Profil cozumlendi: {pp_path}")

    # 2. Provisioning Profile UUID'sini çıkar ve sistem dizinine yerleştir
    profiles_dir = os.path.expanduser('~/Library/MobileDevice/Provisioning Profiles')
    os.makedirs(profiles_dir, exist_ok=True)

    try:
        output = subprocess.check_output(['security', 'cms', '-D', '-i', pp_path])
        plist = plistlib.loads(output)
        uuid = plist.get('UUID', 'embedded')
        target_path = os.path.join(profiles_dir, f"{uuid}.mobileprovision")
        shutil.copyfile(pp_path, target_path)
        print(f"✅ Provisioning Profile yuklendi: {target_path}")
    except Exception as e:
        print(f"⚠️ UUID cikarilamadi, standart isimle kopyalaniyor: {e}")
        shutil.copyfile(pp_path, os.path.join(profiles_dir, "app.mobileprovision"))

if __name__ == '__main__':
    main()
