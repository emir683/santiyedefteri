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
    keychain_path = os.path.join(runner_temp, 'app-signing.keychain-db')
    keychain_pass = "emrcoretempkeychain987"

    cert_b64 = os.environ.get('BUILD_CERTIFICATE_BASE64', '').strip()
    pp_b64 = os.environ.get('BUILD_PROVISION_PROFILE_BASE64', '').strip()
    p12_pass = os.environ.get('P12_PASSWORD', '').strip()

    log("### 🔍 Keychain & Sertifika Kurulumu")
    log(f"- `BUILD_CERTIFICATE_BASE64` boyutu: {len(cert_b64)} karakter")
    log(f"- `BUILD_PROVISION_PROFILE_BASE64` boyutu: {len(pp_b64)} karakter")

    if not cert_b64:
        log("❌ **HATA: `BUILD_CERTIFICATE_BASE64` secret bulunamadi!**")
        sys.exit(1)
    if not pp_b64:
        log("❌ **HATA: `BUILD_PROVISION_PROFILE_BASE64` secret bulunamadi!**")
        sys.exit(1)

    # 1. Base64 verisini çöz
    try:
        cert_data = base64.b64decode(cert_b64)
    except Exception as e:
        log(f"❌ Base64 çözme hatası: {e}")
        sys.exit(1)

    # PEM mi yoksa P12 mi kontrol et
    if b'BEGIN CERTIFICATE' in cert_data or b'BEGIN PRIVATE KEY' in cert_data:
        log("ℹ️ Sertifika PEM formatında algılandı. macOS yerel LibreSSL ile PKCS#12 oluşturuluyor...")
        pem_path = os.path.join(runner_temp, 'combined.pem')
        with open(pem_path, 'wb') as f:
            f.write(cert_data)

        # macOS LibreSSL ile doğrudan macOS uyumlu P12 üret
        p12_pass = "macostemp123"
        export_cmd = [
            'openssl', 'pkcs12', '-export',
            '-in', pem_path,
            '-inkey', pem_path,
            '-out', cert_path,
            '-passout', f'pass:{p12_pass}',
            '-name', 'Apple Distribution: Emircan Ciftci (QML2RQ244F)'
        ]
        res = subprocess.run(export_cmd, capture_output=True, text=True)
        if res.returncode != 0:
            log(f"❌ openssl pkcs12 export hatası: {res.stderr}")
            sys.exit(1)
        log(f"✅ macOS uyumlu P12 başarıyla oluşturuldu: `{cert_path}`")
    else:
        # Zaten P12
        with open(cert_path, 'wb') as f:
            f.write(cert_data)
        log(f"✅ P12 dosyası kaydedildi: `{cert_path}`")

    # 2. Provisioning Profile dosyasını çöz ve kur
    try:
        pp_data = base64.b64decode(pp_b64)
        with open(pp_path, 'wb') as f:
            f.write(pp_data)
        log(f"✅ Profil çözümlendi: `{pp_path}` ({len(pp_data)} bytes)")
    except Exception as e:
        log(f"❌ Profil Base64 çözme hatası: {e}")
        sys.exit(1)

    # Provisioning Profile UUID ile macOS sistem dizinine yerleştir
    profiles_dir = os.path.expanduser('~/Library/MobileDevice/Provisioning Profiles')
    os.makedirs(profiles_dir, exist_ok=True)
    try:
        output = subprocess.check_output(['security', 'cms', '-D', '-i', pp_path])
        plist = plistlib.loads(output)
        uuid = plist.get('UUID', 'embedded')
        target_path = os.path.join(profiles_dir, f"{uuid}.mobileprovision")
        shutil.copyfile(pp_path, target_path)
        log(f"✅ Provisioning Profile sisteme yüklendi: `{uuid}.mobileprovision`")
    except Exception as e:
        log(f"⚠️ UUID çıkarılamadı, standart isimle kopyalanıyor: {e}")
        shutil.copyfile(pp_path, os.path.join(profiles_dir, "app.mobileprovision"))

    # 3. Geçici Keychain Oluştur
    subprocess.run(['security', 'create-keychain', '-p', keychain_pass, keychain_path], check=True)
    subprocess.run(['security', 'set-keychain-settings', '-lut', '21600', keychain_path], check=True)
    subprocess.run(['security', 'unlock-keychain', '-p', keychain_pass, keychain_path], check=True)

    # 4. P12 Sertifikasını Keychain'e Aktar
    log(f"🔑 Sertifika Keychain'e aktarılıyor (Parola: {'[Ayarlı]' if p12_pass else '[Boş]'})")
    import_cmd = [
        'security', 'import', cert_path,
        '-P', p12_pass,
        '-A', '-t', 'cert', '-f', 'pkcs12',
        '-k', keychain_path
    ]
    res_import = subprocess.run(import_cmd, capture_output=True, text=True)
    if res_import.returncode != 0:
        log(f"❌ security import hatası: {res_import.stderr.strip()}")
        sys.exit(1)
    log("✅ Sertifika başarıyla Keychain'e aktarıldı!")

    # 5. Partition List ve Keychain Listesini Güncelle
    subprocess.run([
        'security', 'set-key-partition-list',
        '-S', 'apple-tool:,apple:,codesign:',
        '-s', '-k', keychain_pass, keychain_path
    ], capture_output=True)

    keychain_list_out = subprocess.check_output(['security', 'list-keychains', '-d', 'user'], text=True)
    existing_keychains = [kc.strip().strip('"') for kc in keychain_list_out.splitlines() if kc.strip()]
    if keychain_path not in existing_keychains:
        new_list = [keychain_path] + existing_keychains
        subprocess.run(['security', 'list-keychains', '-d', 'user', '-s'] + new_list, check=True)
    log("✅ Keychain arama listesi güncellendi.")

if __name__ == '__main__':
    main()
