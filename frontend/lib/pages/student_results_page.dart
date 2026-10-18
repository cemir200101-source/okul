// lib/pages/student_results_page.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class StudentResultsPage extends StatefulWidget {
  final int ogrenciId;
  final String ogrenciAdi;

  const StudentResultsPage({
    super.key,
    required this.ogrenciId,
    required this.ogrenciAdi,
  });

  @override
  State<StudentResultsPage> createState() => _StudentResultsPageState();
}

class _StudentResultsPageState extends State<StudentResultsPage> {
  final _api = ApiService();
  late Future<List<dynamic>> _futureResults;
  late Future<Map<String, dynamic>> _futureSubjectPerformance;

  @override
  void initState() {
    super.initState();
    _futureResults = _api.getStudentResults(widget.ogrenciId);
    _futureSubjectPerformance = _api.getStudentSubjectPerformance(widget.ogrenciId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.ogrenciAdi} - Sınav Sonuçları"),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureResults,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Hata: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return const Center(
              child: Text("Bu öğrenci için kayıtlı sınav sonucu bulunamadı."),
            );
          }

          return Column(
            children: [
              // Ders Bazlı Performans Grafiği
              FutureBuilder<Map<String, dynamic>>(
                future: _futureSubjectPerformance,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasData && snapshot.data != null) {
                    final dersler = snapshot.data!['dersler'] as List<dynamic>? ?? [];
                    if (dersler.length >= 2) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Ders Bazında Performans",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: SizedBox(
                                  height: 250,
                                  child: _buildSubjectPerformanceChart(dersler),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Performans Trendi Grafiği
              if (results.length >= 2) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Performans Trendi",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            height: 250,
                            child: _buildPerformanceTrendChart(results),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],

              // Sınav Sonuçları Listesi
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                    final item = results[index] as Map<String, dynamic>;
                    final sinavAdi = item['sinav_adi'] ?? 'Sınav';
                    final tarih = item['tarih'] ?? '';
                    final dersAdi = item['ders_adi'] ?? '';
                    final puan = item['puan'];
                    final net = item['net'];
                    final sinifSira = item['sinif_sira'];
                    final okulSira = item['okul_sira'];
                    final ilceSira = item['ilce_sira'];
                    final ilSira = item['il_sira'];
                    final genelSira = item['genel_sira'];

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ExpansionTile(
                        title: Text(
                          sinavAdi,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            if (dersAdi != '')
                              Text(
                                "Ders: $dersAdi",
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            Text(
                              "Tarih: $tarih",
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            if (puan != null)
                              Text(
                                "Puan: $puan",
                                style: TextStyle(
                                    color: Colors.blueGrey[900],
                                    fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.indigo,
                          child: Text(
                            puan != null ? puan.round().toString() : "?",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (net != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle,
                                          size: 18, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Net: $net",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 12),
                                const Text(
                                  "Sıralamalar:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (sinifSira != null)
                                  _buildRankRow(
                                      "Sınıf Sırası", sinifSira, Icons.class_),
                                if (okulSira != null)
                                  _buildRankRow(
                                      "Okul Sırası", okulSira, Icons.school),
                                if (ilceSira != null)
                                  _buildRankRow("İlçe Sırası", ilceSira,
                                      Icons.location_city),
                                if (ilSira != null)
                                  _buildRankRow(
                                      "İl Sırası", ilSira, Icons.map),
                                if (genelSira != null)
                                  _buildRankRow("Genel Sıra", genelSira,
                                      Icons.emoji_events),
                                if (sinifSira == null &&
                                    okulSira == null &&
                                    ilceSira == null &&
                                    ilSira == null &&
                                    genelSira == null)
                                  Text(
                                    "Sıralama bilgisi bulunmuyor",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPerformanceTrendChart(List<dynamic> results) {
    // Filter results with valid scores and sort by date (oldest first for chart)
    final validResults = results.where((r) => r['puan'] != null && r['tarih'] != null).toList();

    if (validResults.isEmpty) {
      return const Center(child: Text("Yeterli veri yok"));
    }

    // Sort by date ascending (oldest first)
    validResults.sort((a, b) {
      final dateA = DateTime.tryParse(a['tarih'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['tarih'] ?? '') ?? DateTime.now();
      return dateA.compareTo(dateB);
    });

    // Prepare data points
    final spots = <FlSpot>[];
    for (int i = 0; i < validResults.length; i++) {
      final puan = (validResults[i]['puan'] ?? 0.0) as num;
      spots.add(FlSpot(i.toDouble(), puan.toDouble()));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yRange = maxY - minY;
    final chartMinY = (minY - yRange * 0.1).clamp(0.0, double.infinity);
    final chartMaxY = maxY + yRange * 0.1;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < validResults.length) {
                  final tarih = validResults[index]['tarih'] ?? '';
                  final parts = tarih.split('-');
                  if (parts.length >= 2) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${parts[2]}/${parts[1]}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
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
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        minX: 0,
        maxX: (validResults.length - 1).toDouble(),
        minY: chartMinY,
        maxY: chartMaxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < validResults.length) {
                  final sinavAdi = validResults[index]['sinav_adi'] ?? 'Sınav';
                  final puan = spot.y.toStringAsFixed(1);
                  return LineTooltipItem(
                    '$sinavAdi\nPuan: $puan',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: Colors.blue,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectPerformanceChart(List<dynamic> dersler) {
    if (dersler.isEmpty) {
      return const Center(child: Text("Veri yok"));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final ders = dersler[group.x.toInt()];
              final dersAdi = ders['ders_adi'] ?? '';
              final ortalama = (ders['ortalama'] ?? 0.0).toStringAsFixed(1);
              final sinavSayisi = ders['sinav_sayisi'] ?? 0;
              return BarTooltipItem(
                '$dersAdi\nOrt: $ortalama\n$sinavSayisi sınav',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < dersler.length) {
                  final dersAdi = dersler[value.toInt()]['ders_adi'] ?? '';
                  // Ders adını kısalt
                  String shortName = dersAdi;
                  if (dersAdi.length > 8) {
                    shortName = '${dersAdi.substring(0, 7)}...';
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      shortName,
                      style: const TextStyle(fontSize: 9),
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
              reservedSize: 35,
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
          horizontalInterval: 20,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          dersler.length,
          (index) {
            final ders = dersler[index];
            final ortalama = (ders['ortalama'] ?? 0.0) as double;

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

  Widget _buildRankRow(String label, int rank, IconData icon) {
    // Sıraya göre renk belirle
    Color rankColor;
    if (rank <= 3) {
      rankColor = Colors.amber;
    } else if (rank <= 10) {
      rankColor = Colors.green;
    } else if (rank <= 50) {
      rankColor = Colors.blue;
    } else {
      rankColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: rankColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rankColor, width: 1.5),
            ),
            child: Text(
              rank.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rankColor,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
