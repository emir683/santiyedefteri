import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firestore_servisi.dart';
import 'user_model.dart';

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

  Future<void> _submitTeamAction() async {
    final user = Provider.of<UserModel>(context, listen: false);

    if (_ekipAdiController.text.isEmpty || _sifreController.text.isEmpty) {
      setState(() => _error = "L\u00fctfen t\u00fcm alanlar\u0131 doldurun.");
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final firestoreServisi = FirestoreServisi(kullaniciId: user.uid);
    String? teamId;
    String? errorMessage;

    try {
      if (_isJoining) {
        teamId = await firestoreServisi.ekibeKatil(
          _ekipAdiController.text.trim(),
          _sifreController.text.trim(),
        );
      } else {
        teamId = await firestoreServisi.yeniEkipOlustur(
          _ekipAdiController.text.trim(),
          _sifreController.text.trim(),
        );
      }
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) return;

    if (teamId != null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() {
      _error =
          errorMessage ?? "\u0130\u015flem ba\u015far\u0131s\u0131z. Bilgileri kontrol edin.";
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isJoining ? "Bir Ekibe Kat\u0131l" : "Yeni Ekip Olu\u015ftur",
        ),
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
                _isJoining
                    ? "Devam etmek i\u00e7in bir ekibe kat\u0131l\u0131n."
                    : "Yeni bir ekip olu\u015fturarak ba\u015flay\u0131n.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _ekipAdiController,
                decoration: InputDecoration(
                  labelText: "Ekip Ad\u0131",
                  prefixIcon: const Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sifreController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Ekip \u015eifresi",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _error,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _submitTeamAction,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isJoining ? "EK\u0130BE KATIL" : "EK\u0130P OLU\u015eTUR",
                    ),
                  ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isJoining = !_isJoining;
                    _error = '';
                  });
                },
                child: Text(
                  _isJoining
                      ? "Veya yeni bir ekip olu\u015ftur"
                      : "Veya mevcut bir ekibe kat\u0131l",
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                "Veya \u015fimdilik ekipsiz devam edin",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_outline),
                label: const Text("Ekipsiz Devam Et"),
                onPressed:
                    _loading
                        ? null
                        : () async {
                          setState(() {
                            _loading = true;
                            _error = '';
                          });

                          final firestoreServisi = FirestoreServisi(
                            kullaniciId: user.uid,
                          );
                          String? teamId;
                          String? errorMessage;

                          try {
                            teamId =
                                await firestoreServisi.kisiselEkipOlustur();
                          } catch (e) {
                            errorMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          }

                          if (!mounted) return;

                          if (teamId != null) {
                            setState(() {
                              _loading = false;
                            });
                          } else {
                            setState(() {
                              _error = errorMessage ?? "Bir hata olu\u015ftu.";
                              _loading = false;
                            });
                          }
                        },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
