// lib/pages/school_dashboard_page.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'school_exam_analysis_page.dart';
import 'class_comparison_page.dart';

class SchoolDashboardPage extends StatefulWidget {
  final int okulId;
  final String okulAdi;

  const SchoolDashboardPage({
    super.key,
    required this.okulId,
    required this.okulAdi,
  });

  @override
  State<SchoolDashboardPage> createState() => _SchoolDashboardPageState();
}

class _SchoolDashboardPageState extends State<SchoolDashboardPage> {
  final _api = ApiService();
  late Future<Map<String, dynamic>> _futureStats;

  @override
  void initState() {
    super.initState();
    _futureStats = _api.getSchoolStatistics(widget.okulId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.okulAdi} - Dashboard"),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureStats,
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

          final stats = snapshot.data!;
          final toplamSinif = stats['toplam_sinif'] ?? 0;
          final toplamOgrenci = stats['toplam_ogrenci'] ?? 0;
          final toplamSinav = stats['toplam_sinav'] ?? 0;
          final ortalamaBasari = stats['ortalama_basari'] ?? 0.0;
          final enBasariliSinif = stats['en_basarili_sinif'];
          final sonSinavlar = stats['son_sinavlar'] as List<dynamic>? ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _futureStats = _api.getSchoolStatistics(widget.okulId);
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İstatistik kartları
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Toplam Sınıf',
                          toplamSinif.toString(),
                          Icons.class_,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Toplam Öğrenci',
                          toplamOgrenci.toString(),
                          Icons.people,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Toplam Sınav',
                          toplamSinav.toString(),
                          Icons.quiz,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Ortalama Başarı',
                          '${ortalamaBasari.toStringAsFixed(1)}',
                          Icons.trending_up,
                          _getScoreColor(ortalamaBasari),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Sınıf karşılaştırma butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClassComparisonPage(
                              okulId: widget.okulId,
                              okulAdi: widget.okulAdi,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('Sınıfları Karşılaştır'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // En başarılı sınıf
                  if (enBasariliSinif != null) ...[
                    Text(
                      'En Başarılı Sınıf',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          enBasariliSinif['sinif_adi'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Ortalama: ${(enBasariliSinif['ortalama'] ?? 0.0).toStringAsFixed(1)}',
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.colorScheme.onSurface.withAlpha(100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Son sınavlar
                  if (sonSinavlar.isNotEmpty) ...[
                    Text(
                      'Son Sınavlar',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...sonSinavlar.map((sinav) {
                      final sinavId = sinav['id'];
                      final sinavAdi = sinav['ad'] ?? 'İsimsiz Sınav';
                      final tarih = sinav['tarih'] ?? '';
                      final dersAdi = sinav['ders_adi'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.quiz,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          title: Text(sinavAdi),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (dersAdi.isNotEmpty)
                                Text('Ders: $dersAdi'),
                              if (tarih.isNotEmpty)
                                Text('Tarih: $tarih'),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: theme.colorScheme.onSurface.withAlpha(100),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SchoolExamAnalysisPage(
                                  sinavId: sinavId,
                                  sinavAdi: sinavAdi,
                                  okulId: widget.okulId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.amber;
    if (score >= 20) return Colors.orange;
    return Colors.red;
  }
}
