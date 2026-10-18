// lib/pages/students_page.dart
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'student_results_page.dart';
import 'class_exam_analysis_page.dart';

class StudentsPage extends StatefulWidget {
  final int sinifId;
  final String sinifAdi;

  const StudentsPage({
    super.key,
    required this.sinifId,
    required this.sinifAdi,
  });

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final _api = ApiService();
  final _searchController = TextEditingController();

  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  bool _loading = true;
  String? _error;
  String _sortBy = 'İsim (A-Z)'; // İsim (A-Z), İsim (Z-A), Numara (Küçük), Numara (Büyük)

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final students = await _api.getStudentsByClass(widget.sinifId);
      setState(() {
        _allStudents = students;
        _filteredStudents = students;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        final ad = (student['ad'] ?? '').toString().toLowerCase();
        final soyad = (student['soyad'] ?? '').toString().toLowerCase();
        final numara = (student['numara'] ?? '').toString().toLowerCase();

        return ad.contains(query) ||
               soyad.contains(query) ||
               numara.contains(query) ||
               '$ad $soyad'.contains(query);
      }).toList();

      // Sıralama
      _sortStudents();
    });
  }

  void _sortStudents() {
    switch (_sortBy) {
      case 'İsim (A-Z)':
        _filteredStudents.sort((a, b) {
          final nameA = '${a['ad'] ?? ''} ${a['soyad'] ?? ''}'.toLowerCase();
          final nameB = '${b['ad'] ?? ''} ${b['soyad'] ?? ''}'.toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;
      case 'İsim (Z-A)':
        _filteredStudents.sort((a, b) {
          final nameA = '${a['ad'] ?? ''} ${a['soyad'] ?? ''}'.toLowerCase();
          final nameB = '${b['ad'] ?? ''} ${b['soyad'] ?? ''}'.toLowerCase();
          return nameB.compareTo(nameA);
        });
        break;
      case 'Numara (Küçük)':
        _filteredStudents.sort((a, b) {
          final numA = int.tryParse(a['numara']?.toString() ?? '0') ?? 0;
          final numB = int.tryParse(b['numara']?.toString() ?? '0') ?? 0;
          return numA.compareTo(numB);
        });
        break;
      case 'Numara (Büyük)':
        _filteredStudents.sort((a, b) {
          final numA = int.tryParse(a['numara']?.toString() ?? '0') ?? 0;
          final numB = int.tryParse(b['numara']?.toString() ?? '0') ?? 0;
          return numB.compareTo(numA);
        });
        break;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.sinifAdi} - Öğrenciler"),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Sınıf Analizi',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClassExamAnalysisPage(
                    sinifId: widget.sinifId,
                    sinifAdi: widget.sinifAdi,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama çubuğu ve Sıralama
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Öğrenci adı, soyadı veya numara ara...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterStudents();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    onChanged: (value) => _filterStudents(),
                  ),
                ),
                const SizedBox(width: 8),
                // Sıralama dropdown
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort, color: theme.colorScheme.primary),
                  tooltip: 'Sırala',
                  onSelected: (value) {
                    setState(() {
                      _sortBy = value;
                      _filterStudents();
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'İsim (A-Z)',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'İsim (A-Z)'
                                ? Icons.check
                                : Icons.sort_by_alpha,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('İsim (A-Z)'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'İsim (Z-A)',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'İsim (Z-A)'
                                ? Icons.check
                                : Icons.sort_by_alpha,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('İsim (Z-A)'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Numara (Küçük)',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'Numara (Küçük)'
                                ? Icons.check
                                : Icons.numbers,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('Numara (Küçük)'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Numara (Büyük)',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'Numara (Büyük)'
                                ? Icons.check
                                : Icons.numbers,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('Numara (Büyük)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Öğrenci listesi
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: theme.colorScheme.error),
                            const SizedBox(height: 16),
                            Text("Hata: $_error"),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadStudents,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Yeniden Dene'),
                            ),
                          ],
                        ),
                      )
                    : _filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 80,
                                  color: theme.colorScheme.primary.withAlpha(100),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Bu sınıfta henüz öğrenci yok'
                                      : 'Arama sonucu bulunamadı',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: theme.colorScheme.onSurface.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final ogr = _filteredStudents[index];
                              final ad = ogr["ad"] ?? "";
                              final soyad = ogr["soyad"] ?? "";
                              final numara = ogr["numara"]?.toString() ?? "";
                              final ogrenciId = ogr["id"];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Delete button (leftmost, red)
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 20),
                                        color: Colors.red,
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Öğrenciyi Sil'),
                                              content: Text(
                                                  '"$ad $soyad" öğrencisini silmek istediğinize emin misiniz?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, false),
                                                  child: const Text('İptal'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, true),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                  ),
                                                  child: const Text('Sil'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true && mounted) {
                                            try {
                                              // API call to delete student
                                              await _api.deleteStudent(ogrenciId);

                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        '"$ad $soyad" öğrencisi silindi'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );

                                                // Listeyi yenile
                                                _loadStudents();
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text('Hata: ${e.toString()}'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        tooltip: 'Sil',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),

                                      // Edit button
                                      IconButton(
                                        icon: const Icon(Icons.settings, size: 20),
                                        color: theme.colorScheme.primary,
                                        onPressed: () async {
                                          final adController = TextEditingController(text: ad);
                                          final soyadController = TextEditingController(text: soyad);
                                          final numaraController = TextEditingController(text: numara);

                                          final result = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Öğrenciyi Düzenle'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  TextField(
                                                    controller: adController,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Ad',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  TextField(
                                                    controller: soyadController,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Soyad',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  TextField(
                                                    controller: numaraController,
                                                    keyboardType: TextInputType.number,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Numara',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('İptal'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: theme.colorScheme.primary,
                                                  ),
                                                  child: const Text('Kaydet'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (result == true && mounted) {
                                            try {
                                              await _api.updateStudent(
                                                ogrenciId,
                                                ad: adController.text,
                                                soyad: soyadController.text,
                                                numara: int.tryParse(numaraController.text) ?? 0,
                                                sinifId: widget.sinifId,
                                              );

                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('"${adController.text} ${soyadController.text}" güncellendi'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );

                                                _loadStudents();
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Hata: ${e.toString()}'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          }

                                          adController.dispose();
                                          soyadController.dispose();
                                          numaraController.dispose();
                                        },
                                        tooltip: 'Düzenle',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    "$ad $soyad",
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: numara.isNotEmpty
                                      ? Text("Numara: $numara")
                                      : null,
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 20,
                                    color: theme.colorScheme.onSurface.withAlpha(100),
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => StudentResultsPage(
                                          ogrenciId: ogrenciId,
                                          ogrenciAdi: "$ad $soyad",
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
