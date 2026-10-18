// lib/pages/class_comparison_page.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class ClassComparisonPage extends StatefulWidget {
  final int okulId;
  final String okulAdi;

  const ClassComparisonPage({
    super.key,
    required this.okulId,
    required this.okulAdi,
  });

  @override
  State<ClassComparisonPage> createState() => _ClassComparisonPageState();
}

class _ClassComparisonPageState extends State<ClassComparisonPage> {
  final _api = ApiService();
  late Future<List<dynamic>> _futureExams;
  int? _selectedExamId;
  String? _selectedExamName;

  @override
  void initState() {
    super.initState();
    _futureExams = _api.getSchoolExams(widget.okulId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.okulAdi} - Sınıf Karşılaştırma"),
      ),
      body: Column(
        children: [
          // Sınav seçici
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Karşılaştırmak için sınav seçin:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<dynamic>>(
                  future: _futureExams,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: SizedBox(
                              height: 40,
                              child: CircularProgressIndicator()));
                    }

                    if (snapshot.hasError) {
                      return Text('Hata: ${snapshot.error}');
                    }

                    final exams = snapshot.data ?? [];
                    if (exams.isEmpty) {
                      return const Text('Henüz sınav yok');
                    }

                    return DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      hint: const Text('Sınav seçin'),
                      value: _selectedExamId,
                      items: exams.map((exam) {
                        final examId = exam['id'] as int;
                        final examName = exam['ad'] ?? 'İsimsiz Sınav';
                        final examDate = exam['tarih'] ?? '';
                        final dersAdi = exam['ders_adi'] ?? '';

                        return DropdownMenuItem<int>(
                          value: examId,
                          child: Text(
                            '$examName${dersAdi.isNotEmpty ? ' - $dersAdi' : ''}${examDate.isNotEmpty ? ' ($examDate)' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final selectedExam =
                              exams.firstWhere((e) => e['id'] == value);
                          setState(() {
                            _selectedExamId = value;
                            _selectedExamName = selectedExam['ad'];
                          });
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // Karşılaştırma sonuçları
          Expanded(
            child: _selectedExamId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.compare_arrows,
                          size: 80,
                          color: theme.colorScheme.primary.withAlpha(100),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sınıfları karşılaştırmak için\nyukarıdan bir sınav seçin',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  )
                : FutureBuilder<Map<String, dynamic>>(
                    future: _api.getSchoolExamClassComparison(
                        widget.okulId, _selectedExamId!),
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
                                style:
                                    TextStyle(color: theme.colorScheme.error),
                              ),
                            ],
                          ),
                        );
                      }

                      final data = snapshot.data!;
                      final siniflar =
                          data['siniflar'] as List<dynamic>? ?? [];

                      if (siniflar.isEmpty) {
                        return const Center(
                          child: Text('Bu sınav için veri bulunamadı'),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Başlık
                            Text(
                              'Sınıf Performans Karşılaştırması',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _selectedExamName ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Grafik
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: SizedBox(
                                  height: 300,
                                  child:
                                      _buildClassComparisonChart(siniflar),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Detaylı liste
                            Text(
                              'Detaylı İstatistikler',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...siniflar.asMap().entries.map((entry) {
                              final index = entry.key;
                              final sinif = entry.value;
                              final sinifAdi = sinif['sinif_adi'] ?? '';
                              final ortalama = sinif['ortalama'] ?? 0.0;
                              final enYuksek = sinif['en_yuksek'] ?? 0.0;
                              final enDusuk = sinif['en_dusuk'] ?? 0.0;
                              final ogrenciSayisi =
                                  sinif['ogrenci_sayisi'] ?? 0;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: index == 0
                                        ? Colors.amber
                                        : theme.colorScheme.primaryContainer,
                                    child: index == 0
                                        ? const Icon(Icons.emoji_events,
                                            color: Colors.white)
                                        : Text('${index + 1}'),
                                  ),
                                  title: Text(
                                    sinifAdi,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    'Ortalama: ${ortalama.toStringAsFixed(1)}',
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          _buildStatRow(
                                            context,
                                            'Öğrenci Sayısı',
                                            ogrenciSayisi.toString(),
                                            Icons.people,
                                          ),
                                          const Divider(),
                                          _buildStatRow(
                                            context,
                                            'Ortalama',
                                            ortalama.toStringAsFixed(2),
                                            Icons.trending_up,
                                          ),
                                          const Divider(),
                                          _buildStatRow(
                                            context,
                                            'En Yüksek',
                                            enYuksek.toStringAsFixed(2),
                                            Icons.arrow_upward,
                                          ),
                                          const Divider(),
                                          _buildStatRow(
                                            context,
                                            'En Düşük',
                                            enDusuk.toStringAsFixed(2),
                                            Icons.arrow_downward,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
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
        .map((s) => (s['ortalama'] ?? 0.0) as double)
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
              final sinifAdi = sinif['sinif_adi'] ?? '';
              final ortalama = (sinif['ortalama'] ?? 0.0).toStringAsFixed(1);
              final ogrenciSayisi = sinif['ogrenci_sayisi'] ?? 0;
              return BarTooltipItem(
                '$sinifAdi\nOrt: $ortalama\n$ogrenciSayisi öğrenci',
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
                if (value.toInt() >= 0 && value.toInt() < siniflar.length) {
                  final sinifAdi = siniflar[value.toInt()]['sinif_adi'] ?? '';
                  String shortName = sinifAdi;
                  if (sinifAdi.length > 8) {
                    shortName = '${sinifAdi.substring(0, 7)}...';
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      shortName,
                      style: const TextStyle(fontSize: 10),
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
            final ortalama = (sinif['ortalama'] ?? 0.0) as double;

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
                  width: 24,
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

  Widget _buildStatRow(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
