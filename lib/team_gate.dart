import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'ana_menu_ekrani.dart'; 

class TeamGate extends StatefulWidget {
  const TeamGate({super.key});

  @override
  State<TeamGate> createState() => _TeamGateState();
}

class _TeamGateState extends State<TeamGate> {
  final _ekipAdiController = TextEditingController();
  final _sifreController = TextEditingController();

  bool _isJoining = true;
  String _error = '';
  bool _loading = false;

  @override
  void dispose() {
    _ekipAdiController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isJoining ? "Bir Ekibe Katıl" : "Yeni Ekip Oluştur"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isJoining ? "Devam etmek için bir ekibe katılın." : "Yeni bir ekip oluşturarak başlayın.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _ekipAdiController,
                decoration: InputDecoration(
                  labelText: "Ekip Adı",
                  prefixIcon: const Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sifreController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Ekip Şifresi",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(_error, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () async {
                        if (_ekipAdiController.text.isEmpty || _sifreController.text.isEmpty) {
                          setState(() => _error = "Lütfen tüm alanları doldurun.");
                          return;
                        }

                        setState(() { _loading = true; _error = ''; });

                        final firestoreServisi = FirestoreServisi(kullaniciId: user.uid);
                        String? teamId;
                        String? errorMessage;

                        try {
                          if (_isJoining) {
                            teamId = await firestoreServisi.ekibeKatil(
                                _ekipAdiController.text.trim(), _sifreController.text.trim());
                          } else {
                            teamId = await firestoreServisi.yeniEkipOlustur(
                                _ekipAdiController.text.trim(), _sifreController.text.trim());
                          }
                        } catch (e) {
                          errorMessage = e.toString().replaceFirst('Exception: ', '');
                        }

                        if (mounted) {
                          if (teamId != null) {
                            Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AnaMenuEkrani(teamId: teamId!)));
                          } else {
                            setState(() {
                              _error = errorMessage ?? "İşlem başarısız. Bilgileri kontrol edin.";
                              _loading = false;
                            });
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_isJoining ? "EKİBE KATIL" : "EKİP OLUŞTUR"),
                    ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() { _isJoining = !_isJoining; _error = ''; });
                },
                child: Text(_isJoining ? "Veya yeni bir ekip oluştur" : "Veya mevcut bir ekibe katıl"),
              )
            ],
          ),
        ),
      ),
    );
  }
}