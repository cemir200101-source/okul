// lib/pages/school_exam_analysis_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/api_service.dart';

class SchoolExamAnalysisPage extends StatefulWidget {
  final int sinavId;
  final String sinavAdi;
  final int okulId;

  const SchoolExamAnalysisPage({
    super.key,
    required this.sinavId,
    required this.sinavAdi,
    required this.okulId,
  });

  @override
  State<SchoolExamAnalysisPage> createState() => _SchoolExamAnalysisPageState();
}

class _SchoolExamAnalysisPageState extends State<SchoolExamAnalysisPage> {
  final _api = ApiService();
  late Future<Map<String, dynamic>> _futureAnalysis;
  late Future<Map<String, dynamic>> _futureClassComparison;

  @override
  void initState() {
    super.initState();
    _futureAnalysis = _api.getSchoolExamAnalysis(widget.okulId, widget.sinavId);
    _futureClassComparison = _api.getSchoolExamClassComparison(widget.okulId, widget.sinavId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sinavAdi),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureAnalysis,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text("Veri bulunamadı."));
          }

          final ortalama = data["ortalama"] ?? 0.0;
          final enYuksek = data["en_yuksek"] ?? 0.0;
          final enDusuk = data["en_dusuk"] ?? 0.0;
          final ogrenciSayisi = data["ogrenci_sayisi"] ?? 0;
          final siralamalar = data["siralamalar"] as List<dynamic>? ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Genel İstatistikler
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Genel İstatistikler",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatRow("Ortalama", ortalama.toStringAsFixed(2)),
                        _buildStatRow("En Yüksek", enYuksek.toStringAsFixed(2)),
                        _buildStatRow("En Düşük", enDusuk.toStringAsFixed(2)),
                        _buildStatRow("Katılımcı Sayısı", ogrenciSayisi.toString()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sınıf Karşılaştırma Grafiği
                const Text(
                  "Sınıf Karşılaştırması",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, dynamic>>(
                  future: _futureClassComparison,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("Sınıf karşılaştırması yüklenemedi."),
                        ),
                      );
                    }

                    final siniflar = snapshot.data!["siniflar"] as List<dynamic>? ?? [];

                    if (siniflar.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("Henüz sınıf verisi yok."),
                        ),
                      );
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          height: 300,
                          child: _buildClassComparisonChart(siniflar),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Öğrenci Sıralaması
                const Text(
                  "Öğrenci Sıralaması",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                if (siralamalar.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("Henüz sonuç girilmemiş."),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: siralamalar.length,
                    itemBuilder: (context, index) {
                      final ogrenci = siralamalar[index];
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
                                color: sira <= 3 ? Colors.white : Colors.black87,
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
                    },
                  ),
              ],
            ),
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
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassComparisonChart(List<dynamic> siniflar) {
    if (siniflar.isEmpty) {
      return const Center(child: Text("Veri yok"));
    }

    final maxOrtalama = siniflar
        .map((s) => (s["ortalama"] ?? 0.0) as double)
        .reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxOrtalama + 10).ceilToDouble(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final sinif = siniflar[group.x.toInt()];
              final sinifAdi = sinif["sinif_adi"] ?? "";
              final ortalama = (sinif["ortalama"] ?? 0.0).toStringAsFixed(2);
              final ogrenciSayisi = sinif["ogrenci_sayisi"] ?? 0;
              return BarTooltipItem(
                '$sinifAdi\nOrt: $ortalama\n$ogrenciSayisi öğrenci',
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
                if (value.toInt() >= 0 && value.toInt() < siniflar.length) {
                  final sinifAdi = siniflar[value.toInt()]["sinif_adi"] ?? "";
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      sinifAdi,
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.center,
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
              reservedSize: 40,
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
          horizontalInterval: 10,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          siniflar.length,
          (index) {
            final sinif = siniflar[index];
            final ortalama = (sinif["ortalama"] ?? 0.0) as double;

            // Renk: performansa göre yeşil-sarı-kırmızı gradient
            Color barColor;
            if (ortalama >= 80) {
              barColor = Colors.green;
            } else if (ortalama >= 60) {
              barColor = Colors.lightGreen;
            } else if (ortalama >= 40) {
              barColor = Colors.amber;
            } else if (ortalama >= 20) {
              barColor = Colors.orange;
            } else {
              barColor = Colors.red;
            }

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: ortalama,
                  color: barColor,
                  width: 22,
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
