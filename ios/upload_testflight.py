#!/usr/bin/env python3
import base64
import os
import subprocess
import sys

def main():
    key_id = os.environ.get('APP_STORE_CONNECT_KEY_ID', '').strip()
    issuer_id = os.environ.get('APP_STORE_CONNECT_ISSUER_ID', '').strip()
    raw_key = os.environ.get('APP_STORE_CONNECT_PRIVATE_KEY', '').strip()

    if not key_id:
        sys.exit("❌ HATA: 'APP_STORE_CONNECT_KEY_ID' secret boş veya eksik!")
    if not issuer_id:
        sys.exit("❌ HATA: 'APP_STORE_CONNECT_ISSUER_ID' secret boş veya eksik!")
    if not raw_key:
        sys.exit("❌ HATA: 'APP_STORE_CONNECT_PRIVATE_KEY' secret boş veya eksik!")

    # 1. Base64 ise çöz
    if 'BEGIN PRIVATE KEY' not in raw_key:
        try:
            raw_key = base64.b64decode(raw_key).decode('utf-8')
        except Exception:
            pass

    # 2. Satırları temizle ve standart Unix PEM formatına getir
    lines = [line.strip() for line in raw_key.replace(r'\n', '\n').splitlines() if line.strip()]
    body = [l for l in lines if 'PRIVATE KEY' not in l]
    clean_pem = '-----BEGIN PRIVATE KEY-----\n' + '\n'.join(body) + '\n-----END PRIVATE KEY-----\n'

    # 3. xcrun altool için hem ~/.private_keys hem ~/.appstoreconnect/private_keys dizinlerine yaz
    for p in ['~/.private_keys', '~/.appstoreconnect/private_keys']:
        d = os.path.expanduser(p)
        os.makedirs(d, exist_ok=True)
        key_file = os.path.join(d, f"AuthKey_{key_id}.p8")
        with open(key_file, 'w', newline='\n', encoding='utf-8') as f:
            f.write(clean_pem)
        print(f"✅ API Anahtarı hazırlandı: {key_file}")

    ipa_path = 'build/ipa_out/app.ipa'
    if not os.path.exists(ipa_path):
        sys.exit(f"❌ HATA: Yüklenecek IPA dosyası bulunamadı: {ipa_path}")

    # 4. Apple altool ile TestFlight'a yükle
    print(f"🚀 xcrun altool ile TestFlight'a yükleniyor ({ipa_path})...")
    upload_cmd = [
        'xcrun', 'altool', '--upload-app',
        '-f', ipa_path,
        '--type', 'ios',
        '--apiKey', key_id,
        '--apiIssuer', issuer_id
    ]

    process = subprocess.Popen(upload_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in iter(process.stdout.readline, ''):
        print(line, end='', flush=True)
    process.stdout.close()
    return_code = process.wait()

    if return_code != 0:
        sys.exit(f"❌ xcrun altool hatayla sonlandı (Kod: {return_code})")

    print("\n🎉 Tebrikler! Uygulama başarıyla TestFlight'a yüklendi!")

if __name__ == '__main__':
    main()
