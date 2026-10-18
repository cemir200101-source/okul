// lib/pages/student_trends_page.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'student_results_page.dart';

class StudentTrendsPage extends StatefulWidget {
  final int sinifId;
  final String sinifAdi;

  const StudentTrendsPage({
    super.key,
    required this.sinifId,
    required this.sinifAdi,
  });

  @override
  State<StudentTrendsPage> createState() => _StudentTrendsPageState();
}

class _StudentTrendsPageState extends State<StudentTrendsPage> {
  final _api = ApiService();
  late Future<Map<String, dynamic>> _futureTrends;
  String _sortBy = 'Trend'; // Trend, İsim, Ortalama

  @override
  void initState() {
    super.initState();
    _futureTrends = _api.getClassSuccessTrends(widget.sinifId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.sinifAdi} - Başarı Trendleri"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sırala',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Trend',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'Trend' ? Icons.check : Icons.trending_up,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Trend (En İyi)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'İsim',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'İsim' ? Icons.check : Icons.sort_by_alpha,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('İsim (A-Z)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Ortalama',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'Ortalama' ? Icons.check : Icons.analytics,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Ortalama (Yüksek)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureTrends,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    "Hata: ${snapshot.error}",
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          var ogrenciler = data['ogrenciler'] as List<dynamic>? ?? [];

          if (ogrenciler.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 80,
                    color: theme.colorScheme.primary.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trend analizi için\nen az 2 sınav gerekli',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                ],
              ),
            );
          }

          // Sıralama
          ogrenciler = List.from(ogrenciler);
          switch (_sortBy) {
            case 'Trend':
              ogrenciler.sort((a, b) =>
                  (b['trend'] as num).compareTo(a['trend'] as num));
              break;
            case 'İsim':
              ogrenciler.sort((a, b) {
                final nameA = '${a['ad']} ${a['soyad']}'.toLowerCase();
                final nameB = '${b['ad']} ${b['soyad']}'.toLowerCase();
                return nameA.compareTo(nameB);
              });
              break;
            case 'Ortalama':
              ogrenciler.sort((a, b) =>
                  (b['ortalama'] as num).compareTo(a['ortalama'] as num));
              break;
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _futureTrends = _api.getClassSuccessTrends(widget.sinifId);
              });
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ogrenciler.length,
              itemBuilder: (context, index) {
                final ogrenci = ogrenciler[index];
                final ogrenciId = ogrenci['ogrenci_id'];
                final ad = ogrenci['ad'] ?? '';
                final soyad = ogrenci['soyad'] ?? '';
                final trend = ogrenci['trend'] ?? 0.0;
                final trendDurumu = ogrenci['trend_durumu'] ?? 'Stabil';
                final ortalama = ogrenci['ortalama'] ?? 0.0;
                final ilkPuan = ogrenci['ilk_puan'] ?? 0.0;
                final sonPuan = ogrenci['son_puan'] ?? 0.0;
                final sinavSayisi = ogrenci['sinav_sayisi'] ?? 0;

                // Trend rengi ve ikonu
                Color trendColor;
                IconData trendIcon;
                if (trendDurumu == 'Yükselen') {
                  trendColor = Colors.green;
                  trendIcon = Icons.trending_up;
                } else if (trendDurumu == 'Düşen') {
                  trendColor = Colors.red;
                  trendIcon = Icons.trending_down;
                } else {
                  trendColor = Colors.grey;
                  trendIcon = Icons.trending_flat;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentResultsPage(
                            ogrenciId: ogrenciId,
                            ogrenciAdi: '$ad $soyad',
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Trend göstergesi
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: trendColor.withAlpha(50),
                              shape: BoxShape.circle,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(trendIcon, color: trendColor, size: 24),
                                Text(
                                  trend >= 0 ? '+${trend.toStringAsFixed(0)}' : trend.toStringAsFixed(0),
                                  style: TextStyle(
                                    color: trendColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Öğrenci bilgileri
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$ad $soyad',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$sinavSayisi sınav • Ort: ${ortalama.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(150),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withAlpha(50),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'İlk: ${ilkPuan.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.arrow_forward,
                                        size: 12,
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(100)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: trendColor.withAlpha(50),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Son: ${sonPuan.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: trendColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // İleri ok
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: theme.colorScheme.onSurface.withAlpha(100),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
