// lib/pages/class_exam_analysis_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../config.dart' as config;
import 'student_trends_page.dart';

class ClassExamAnalysisPage extends StatefulWidget {
  final int sinifId;
  final String sinifAdi;

  const ClassExamAnalysisPage({
    super.key,
    required this.sinifId,
    required this.sinifAdi,
  });

  @override
  State<ClassExamAnalysisPage> createState() => _ClassExamAnalysisPageState();
}

class _ClassExamAnalysisPageState extends State<ClassExamAnalysisPage> {
  final _api = ApiService();
  late Future<List<dynamic>> _futureExams;

  @override
  void initState() {
    super.initState();
    _futureExams = _api.getClassExams(widget.sinifId);
  }

  Future<void> _exportToExcel(int sinavId) async {
    try {
      // Token'ı al
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oturum süresi dolmuş, lütfen tekrar giriş yapın')),
          );
        }
        return;
      }

      // URL'yi oluştur
      final url = Uri.parse('${config.baseUrl}/exports/sinif-analiz/excel?sinif_id=${widget.sinifId}&sinav_id=$sinavId');

      // Token ile URL'yi tarayıcıda aç
      final urlWithToken = url.replace(queryParameters: {
        ...url.queryParameters,
        'token': token,
      });

      if (await canLaunchUrl(urlWithToken)) {
        await launchUrl(urlWithToken, mode: LaunchMode.externalApplication);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel dosyası indiriliyor...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İndirme başlatılamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExamAnalysis(int sinavId, String sinavAdi) async {
    final analysis = await _api.getClassExamAnalysis(widget.sinifId, sinavId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final ortalama = analysis["ortalama"] ?? 0.0;
        final enYuksek = analysis["en_yuksek"] ?? 0.0;
        final enDusuk = analysis["en_dusuk"] ?? 0.0;
        final ogrenciSayisi = analysis["ogrenci_sayisi"] ?? 0;
        final siralamalar = analysis["siralamalar"] as List<dynamic>? ?? [];

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                child: ListView(
                  controller: scrollController,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            sinavAdi,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download),
                          tooltip: 'Excel\'e Aktar',
                          onPressed: () => _exportToExcel(sinavId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Genel İstatistikler
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Sınıf İstatistikleri",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildStatRow("Ortalama", ortalama.toStringAsFixed(2)),
                            _buildStatRow("En Yüksek", enYuksek.toStringAsFixed(2)),
                            _buildStatRow("En Düşük", enDusuk.toStringAsFixed(2)),
                            _buildStatRow("Katılımcı", ogrenciSayisi.toString()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Puan Dağılım Grafiği
                    if (siralamalar.isNotEmpty) ...[
                      const Text(
                        "Puan Dağılımı",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            height: 200,
                            child: _buildScoreDistributionChart(siralamalar),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      "Sınıf Sıralaması",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Liste elemanları
                    if (siralamalar.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text("Henüz sonuç yok.")),
                      )
                    else
                      ...siralamalar.asMap().entries.map((entry) {
                        final index = entry.key;
                        final ogrenci = entry.value;
                        final ad = ogrenci["ad"] ?? "";
                        final soyad = ogrenci["soyad"] ?? "";
                        final puan = ogrenci["puan"] ?? 0.0;
                        final sira = index + 1;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: sira <= 3
                                  ? Colors.amber
                                  : Colors.blue.shade100,
                              child: Text(
                                sira.toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: sira <= 3
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            title: Text("$ad $soyad"),
                            trailing: Text(
                              puan.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.sinifAdi} - Sınav Analizi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.trending_up),
            tooltip: 'Başarı Trendleri',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentTrendsPage(
                    sinifId: widget.sinifId,
                    sinifAdi: widget.sinifAdi,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureExams,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }

          final sinavlar = snapshot.data ?? [];

          if (sinavlar.isEmpty) {
            return const Center(
              child: Text("Bu sınıf için henüz sınav sonucu yok."),
            );
          }

          return ListView.builder(
            itemCount: sinavlar.length,
            itemBuilder: (context, index) {
              final sinav = sinavlar[index];
              final sinavId = sinav["id"];
              final sinavAdi = sinav["ad"] ?? "İsimsiz Sınav";
              final dersAdi = sinav["ders_adi"] ?? "";
              final tarih = sinav["tarih"] ?? "";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(sinavAdi),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dersAdi.isNotEmpty) Text("Ders: $dersAdi"),
                      if (tarih.isNotEmpty) Text("Tarih: $tarih"),
                    ],
                  ),
                  trailing: const Icon(Icons.analytics, size: 20),
                  onTap: () => _showExamAnalysis(sinavId, sinavAdi),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDistributionChart(List<dynamic> siralamalar) {
    // Puanları grupla (0-20, 21-40, 41-60, 61-80, 81-100)
    Map<String, int> distribution = {
      '0-20': 0,
      '21-40': 0,
      '41-60': 0,
      '61-80': 0,
      '81-100': 0,
    };

    for (var ogrenci in siralamalar) {
      final puan = (ogrenci['puan'] ?? 0.0).toDouble();
      if (puan >= 0 && puan <= 20) {
        distribution['0-20'] = distribution['0-20']! + 1;
      } else if (puan >= 21 && puan <= 40) {
        distribution['21-40'] = distribution['21-40']! + 1;
      } else if (puan >= 41 && puan <= 60) {
        distribution['41-60'] = distribution['41-60']! + 1;
      } else if (puan >= 61 && puan <= 80) {
        distribution['61-80'] = distribution['61-80']! + 1;
      } else if (puan >= 81 && puan <= 100) {
        distribution['81-100'] = distribution['81-100']! + 1;
      }
    }

    final maxValue = distribution.values.reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue + 2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = distribution.keys.elementAt(group.x.toInt());
              return BarTooltipItem(
                '$label\n${rod.toY.toInt()} öğrenci',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final labels = distribution.keys.toList();
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          distribution.length,
          (index) {
            final count = distribution.values.elementAt(index).toDouble();
            Color barColor;

            // Renk kodlaması: düşük puan kırmızı, yüksek puan yeşil
            switch (index) {
              case 0:
                barColor = Colors.red;
                break;
              case 1:
                barColor = Colors.orange;
                break;
              case 2:
                barColor = Colors.amber;
                break;
              case 3:
                barColor = Colors.lightGreen;
                break;
              case 4:
                barColor = Colors.green;
                break;
              default:
                barColor = Colors.blue;
            }

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: count,
                  color: barColor,
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
