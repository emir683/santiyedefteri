#!/usr/bin/env python3
import base64
import os
import re
import subprocess
import sys

def main():
    raw_key_id = (
        os.environ.get('APP_STORE_CONNECT_KEY_ID') or
        os.environ.get('APPSTORE_API_KEY_ID') or
        os.environ.get('APPSTORE_KEY_ID') or
        'CQ6NJF8X8Q'
    )
    raw_issuer_id = (
        os.environ.get('APP_STORE_CONNECT_ISSUER_ID') or
        os.environ.get('APPSTORE_ISSUER_ID') or
        '4e4eebba-56b8-450f-9a64-1310de60a145'
    )
    raw_key = (
        os.environ.get('APP_STORE_CONNECT_PRIVATE_KEY') or
        os.environ.get('APPSTORE_API_PRIVATE_KEY') or
        os.environ.get('APPSTORE_PRIVATE_KEY') or
        os.environ.get('API_PRIVATE_KEY') or
        ''
    ).strip()

    # ID'leri temizle (whitespace, \r, \n temizliği)
    key_id = re.sub(r'[^A-Za-z0-9]', '', raw_key_id)
    issuer_id = re.sub(r'[^A-Za-z0-9\-]', '', raw_issuer_id)

    if not raw_key:
        sys.exit("❌ HATA: 'APP_STORE_CONNECT_PRIVATE_KEY' secret GitHub ayarlarında boş veya eklenmemiş!")

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

    # 3. xcrun altool için hem proje içine hem sistem dizinlerine yaz
    target_dirs = [
        os.path.abspath('private_keys'),
        os.path.expanduser('~/private_keys'),
        os.path.expanduser('~/.private_keys'),
        os.path.expanduser('~/.appstoreconnect/private_keys')
    ]

    for d in target_dirs:
        try:
            os.makedirs(d, exist_ok=True)
            key_file = os.path.join(d, f"AuthKey_{key_id}.p8")
            with open(key_file, 'wb') as f:
                f.write(clean_pem.encode('utf-8'))
            print(f"✅ API Anahtarı yazıldı: {key_file} ({os.path.getsize(key_file)} bytes)")
        except Exception as e:
            print(f"⚠️ {d} dizinine yazılamadı: {e}")

    os.environ['API_PRIVATE_KEYS_DIR'] = os.path.abspath('private_keys')

    # IPA dosyasını bul
    ipa_path = 'build/ipa_out/app.ipa'
    if not os.path.exists(ipa_path):
        # build/ipa_out altındaki herhangi bir ipa'yı ara
        if os.path.exists('build/ipa_out'):
            ipas = [f for f in os.listdir('build/ipa_out') if f.endswith('.ipa')]
            if ipas:
                ipa_path = os.path.join('build/ipa_out', ipas[0])
            else:
                sys.exit("❌ HATA: 'build/ipa_out' klasöründe .ipa dosyası bulunamadı!")
        else:
            sys.exit(f"❌ HATA: Yüklenecek IPA dosyası bulunamadı: {ipa_path}")

    print(f"📦 Yüklenecek IPA: {ipa_path} ({os.path.getsize(ipa_path)} bytes)")
    print(f"🚀 Apple TestFlight'a yükleme başlatılıyor (Key: {key_id}, Issuer: {issuer_id})...")

    # 4. Apple altool ile TestFlight'a yükle
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
        sys.exit(f"\n❌ xcrun altool hatayla sonlandı (Çıkış Kodu: {return_code})")

    print("\n🎉 Tebrikler! Uygulama başarıyla TestFlight'a yüklendi!")

if __name__ == '__main__':
    main()
