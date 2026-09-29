import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'il_ilce_secici_modal.dart';

class WeatherDashboardCard extends StatefulWidget {
  const WeatherDashboardCard({super.key});

  @override
  State<WeatherDashboardCard> createState() => _WeatherDashboardCardState();
}

class _WeatherDashboardCardState extends State<WeatherDashboardCard> {
  String? _locationName;
  Map<String, dynamic>? _currentWeather;
  List<dynamic>? _dailyWeather;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLocationAndWeather();
  }

  Future<void> _loadLocationAndWeather() async {
    final prefs = await SharedPreferences.getInstance();
    final locName = prefs.getString('weather_location_name');
    final lat = prefs.getDouble('weather_lat');
    final lon = prefs.getDouble('weather_lon');
    
    if (locName != null && lat != null && lon != null) {
      _locationName = locName;
      await _fetchWeatherDirectly(lat, lon);
    } else {
      final oldLoc = prefs.getString('weather_location');
      if (oldLoc != null && oldLoc.isNotEmpty) {
        _locationName = oldLoc;
        await _fetchWeather(oldLoc);
      } else {
        if (mounted) {
          setState(() {
            _locationName = null;
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _fetchWeather(String location) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final geoUrl = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$location&count=1&language=tr&format=json');
      final geoRes = await http.get(geoUrl);
      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        if (geoData['results'] != null && geoData['results'].isNotEmpty) {
          final lat = geoData['results'][0]['latitude'];
          final lon = geoData['results'][0]['longitude'];
          
          final weatherUrl = Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&daily=temperature_2m_max,temperature_2m_min,weathercode&timezone=auto');
          final weatherRes = await http.get(weatherUrl);
          
          if (weatherRes.statusCode == 200) {
            final wData = jsonDecode(weatherRes.body);
            if (mounted) {
              setState(() {
                _currentWeather = wData['current_weather'];
                _dailyWeather = wData['daily'] != null ? List.generate(
                  wData['daily']['time'].length,
                  (i) => {
                    'time': wData['daily']['time'][i],
                    'max': wData['daily']['temperature_2m_max'][i],
                    'min': wData['daily']['temperature_2m_min'][i],
                    'code': wData['daily']['weathercode'][i],
                  }
                ) : null;
                _isLoading = false;
              });
            }
            return;
          }
        }
      }
      throw Exception("Hava durumu bulunamadı.");
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Veri alınamadı.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchWeatherDirectly(double lat, double lon) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final weatherUrl = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&daily=temperature_2m_max,temperature_2m_min,weathercode&timezone=auto');
      final weatherRes = await http.get(weatherUrl);
      
      if (weatherRes.statusCode == 200) {
        final wData = jsonDecode(weatherRes.body);
        if (mounted) {
          setState(() {
            _currentWeather = wData['current_weather'];
            _dailyWeather = wData['daily'] != null ? List.generate(
              wData['daily']['time'].length,
              (i) => {
                'time': wData['daily']['time'][i],
                'max': wData['daily']['temperature_2m_max'][i],
                'min': wData['daily']['temperature_2m_min'][i],
                'code': wData['daily']['weathercode'][i],
              }
            ) : null;
            _isLoading = false;
          });
        }
        return;
      }
      throw Exception("Hava durumu bulunamadı.");
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Veri alınamadı.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showLocationDialog() async {
    final result = await IlIlceSeciciModal.goster(context);

    if (result != null) {
      final locName = result.tamKonum;
      final lat = result.lat ?? 39.9334;
      final lon = result.lon ?? 32.8597;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('weather_location_name', locName);
      await prefs.setDouble('weather_lat', lat);
      await prefs.setDouble('weather_lon', lon);
      setState(() {
        _locationName = locName;
      });
      _fetchWeatherDirectly(lat, lon);
    }
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 3) return Icons.cloud_rounded;
    if (code <= 48) return Icons.foggy;
    if (code <= 67) return Icons.water_drop_rounded;
    if (code <= 77) return Icons.ac_unit_rounded;
    if (code <= 82) return Icons.grain_rounded;
    if (code <= 99) return Icons.flash_on_rounded;
    return Icons.wb_cloudy_rounded;
  }

  String _getWeatherDesc(int code) {
    if (code == 0) return "Açık";
    if (code == 1 || code == 2 || code == 3) return "Parçalı Bulutlu";
    if (code <= 48) return "Sisli";
    if (code <= 67) return "Yağmurlu";
    if (code <= 77) return "Karlı";
    if (code <= 82) return "Sağanak Yağış";
    if (code <= 99) return "Fırtına";
    return "Bulutlu";
  }

  Widget _buildPanelGlassCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(18)}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isDark ? const Color(0xFF15181D) : const Color(0xFFE7EEF1))
                .withValues(alpha: isDark ? 0.96 : 0.90),
            (isDark ? const Color(0xFF090B0F) : const Color(0xFFD6E1E6))
                .withValues(alpha: isDark ? 0.98 : 0.94),
          ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFBFD0D6).withValues(alpha: 0.92),
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: isDark ? 18 : 12,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF79E9D7).withValues(alpha: isDark ? 0.03 : 0.08),
            blurRadius: isDark ? 12 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _buildPanelGlassInset({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(14)}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isDark ? const Color(0xFF171A1F) : const Color(0xFFE0EAEE)).withValues(alpha: isDark ? 0.88 : 0.82),
            (isDark ? const Color(0xFF0D0F13) : const Color(0xFFCCD9DE)).withValues(alpha: isDark ? 0.96 : 0.90),
          ],
        ),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFBFD0D6).withValues(alpha: 0.88),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  void _showExpandedWeatherCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Hero(
                    tag: 'weather_dashboard_card',
                    flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                      return Material(type: MaterialType.transparency, child: toHeroContext.widget);
                    },
                    child: Material(
                      type: MaterialType.transparency,
                      child: _buildPanelGlassCard(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '5 Günlük Tahmin',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF102A43),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_dailyWeather == null)
                                Text('Tahmin verisi bulunamadı.', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))
                              else
                                ..._dailyWeather!.take(5).map((day) {
                                  final code = day['code'] as int;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: _buildPanelGlassInset(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            day['time'].toString().substring(5), // YYYY-MM-DD -> MM-DD
                                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                          ),
                                          Row(
                                            children: [
                                              Icon(_getWeatherIcon(code), size: 18, color: isDark ? Colors.white70 : const Color(0xFF0F7C86)),
                                              const SizedBox(width: 8),
                                              Text(_getWeatherDesc(code), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                                            ],
                                          ),
                                          Text(
                                            '${day['min']}° / ${day['max']}°',
                                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;
    
    if (_locationName == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Hava Durumu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF102A43))),
              Icon(Icons.cloud_outlined, color: isDark ? Colors.white54 : Colors.black45),
            ],
          ),
          const SizedBox(height: 12),
          Text("Konum seçerek hava durumunu takip edin.", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showLocationDialog,
            icon: const Icon(Icons.location_on_rounded, size: 16),
            label: const Text("Konum Ayarla"),
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], foregroundColor: isDark ? Colors.white : Colors.black87, elevation: 0),
          )
        ],
      );
    } else if (_isLoading) {
      content = const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
    } else if (_errorMessage != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_locationName!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF102A43))),
              IconButton(icon: Icon(Icons.edit_location_alt_rounded, color: isDark ? Colors.white54 : Colors.black45), onPressed: _showLocationDialog, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
          ),
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
        ],
      );
    } else if (_currentWeather != null) {
      final code = _currentWeather!['weathercode'] as int;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_locationName!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF102A43))),
              IconButton(icon: Icon(Icons.edit_location_alt_rounded, color: isDark ? Colors.white54 : Colors.black45), onPressed: _showLocationDialog, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_getWeatherIcon(code), size: 48, color: isDark ? Colors.white : const Color(0xFF0F7C86)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_currentWeather!['temperature']}°C', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF102A43))),
                  Text(_getWeatherDesc(code), style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
                ],
              ),
              const Spacer(),
              _buildPanelGlassInset(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.air, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                    const SizedBox(width: 4),
                    Text('${_currentWeather!['windspeed']} km/s', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      content = const SizedBox.shrink();
    }

    Widget card = _buildPanelGlassCard(child: content);

    if (_currentWeather != null) {
      card = GestureDetector(
        onTap: _showExpandedWeatherCard,
        child: Hero(
          tag: 'weather_dashboard_card',
          flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
            return Material(type: MaterialType.transparency, child: toHeroContext.widget);
          },
          child: Material(
            type: MaterialType.transparency,
            child: card,
          ),
        ),
      );
    }

    return card;
  }
}

class _LocationSearchDialog extends StatefulWidget {
  const _LocationSearchDialog();

  @override
  State<_LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<_LocationSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _results = [];
  bool _isSearching = false;
  String? _error;

  void _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final geoUrl = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(query)}&count=5&language=tr&format=json');
      final geoRes = await http.get(geoUrl);
      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        if (mounted) {
          setState(() {
            _results = geoData['results'] ?? [];
            _isSearching = false;
          });
        }
      } else {
        throw Exception("API Hatası");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Arama sırasında bir hata oluştu.";
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: const Text("Konum Ara"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Şehir veya İlçe arayın...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _searchLocation('');
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) {
                // Basit bir debounce simülasyonu yerine anında arama (open-meteo hızlıdır)
                _searchLocation(val);
              },
              onSubmitted: (val) {
                if (val.trim().isNotEmpty && _results.isNotEmpty) {
                    final item = _results[0];
                    final name = item['name'] ?? '';
                    final admin1 = item['admin1'] ?? '';
                    final country = item['country'] ?? '';
                    String displayName = name;
                    if (admin1.isNotEmpty && admin1 != name) {
                      displayName += ", $admin1";
                    } else if (country.isNotEmpty && country != name) {
                      displayName += ", $country";
                    }
                    Navigator.pop(context, {
                      'name': displayName,
                      'lat': item['latitude'],
                      'lon': item['longitude'],
                    });
                }
              },
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const CircularProgressIndicator()
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    final name = item['name'] ?? '';
                    final admin1 = item['admin1'] ?? '';
                    final country = item['country'] ?? '';
                    
                    String displayName = name;
                    if (admin1.isNotEmpty && admin1 != name) {
                      displayName += ", $admin1";
                    } else if (country.isNotEmpty && country != name) {
                      displayName += ", $country";
                    }

                    return ListTile(
                      leading: const Icon(Icons.location_city_rounded),
                      title: Text(displayName),
                      onTap: () {
                        Navigator.pop(context, {
                          'name': displayName,
                          'lat': item['latitude'],
                          'lon': item['longitude'],
                        });
                      },
                    );
                  },
                ),
              )
            else if (_controller.text.trim().isNotEmpty)
              const Text("Sonuç bulunamadı.")
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
      ],
    );
  }
}
