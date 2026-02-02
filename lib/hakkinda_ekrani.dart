import 'package:flutter/material.dart';
// import 'package:package_info_plus/package_info_plus.dart'; // BU SATIRI SİLDİK VEYA YORUMA ALDIK

class HakkindaEkrani extends StatelessWidget {
  const HakkindaEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(title: const Text("Hakkında")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO ALANI
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.construction, size: 80, color: Colors.green),
              ),
              const SizedBox(height: 24),
              
              Text(
                "Şantiye Defteri",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "Profesyonel Saha Yönetimi",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              
              const SizedBox(height: 40),
              
              // BİLGİ KARTI
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    _buildRow("Versiyon", "1.0.0"), // BURAYI ELLE YAZDIK
                    const Divider(),
                    _buildRow("Geliştirici", "Emir Çiftçi"),
                    const Divider(),
                    _buildRow("İletişim", "destek@santiyeapp.com"),
                  ],
                ),
              ),
              
              const Spacer(),
              Text("© 2025 Tüm Hakları Saklıdır", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}