#!/usr/bin/env python3
import base64
import os
import plistlib
import shutil
import subprocess
import sys

def log(msg):
    print(msg)
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        try:
            with open(summary_path, 'a', encoding='utf-8') as f:
                f.write(msg + '\n')
        except Exception:
            pass

def main():
    runner_temp = os.environ.get('RUNNER_TEMP', '/tmp')
    cert_path = os.path.join(runner_temp, 'build_certificate.p12')
    pp_path = os.path.join(runner_temp, 'build_pp.mobileprovision')

    cert_b64 = os.environ.get('BUILD_CERTIFICATE_BASE64', '').strip()
    pp_b64 = os.environ.get('BUILD_PROVISION_PROFILE_BASE64', '').strip()
    p12_pass = os.environ.get('P12_PASSWORD', '').strip()

    log("### 🔍 Keychain & Sertifika Kontrolü")
    log(f"- `BUILD_CERTIFICATE_BASE64` uzunluğu: {len(cert_b64)} karakter")
    log(f"- `BUILD_PROVISION_PROFILE_BASE64` uzunluğu: {len(pp_b64)} karakter")
    log(f"- `P12_PASSWORD` ayarlı mı: {'EVET' if bool(p12_pass) else 'HAYIR'}")

    if not cert_b64:
        log("❌ **HATA: `BUILD_CERTIFICATE_BASE64` GitHub Secret'ı boş veya eklenmemiş!**")
        sys.exit(1)
    if not pp_b64:
        log("❌ **HATA: `BUILD_PROVISION_PROFILE_BASE64` GitHub Secret'ı boş veya eklenmemiş!**")
        sys.exit(1)
    if not p12_pass:
        log("❌ **HATA: `P12_PASSWORD` GitHub Secret'ı boş veya eklenmemiş!**")
        sys.exit(1)

    # 1. Base64 çöz ve kaydet
    try:
        with open(cert_path, 'wb') as f:
            f.write(base64.b64decode(cert_b64))
        log(f"✅ Sertifika çözümlendi: `{cert_path}` ({os.path.getsize(cert_path)} bytes)")
    except Exception as e:
        log(f"❌ Sertifika Base64 çözüm hatası: {e}")
        sys.exit(1)

    try:
        with open(pp_path, 'wb') as f:
            f.write(base64.b64decode(pp_b64))
        log(f"✅ Profil çözümlendi: `{pp_path}` ({os.path.getsize(pp_path)} bytes)")
    except Exception as e:
        log(f"❌ Profil Base64 çözüm hatası: {e}")
        sys.exit(1)

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
