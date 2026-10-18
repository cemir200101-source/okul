// lib/pages/school_exams_list_page.dart
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'school_exam_analysis_page.dart';
import 'school_dashboard_page.dart';

class SchoolExamsListPage extends StatefulWidget {
  final int okulId;
  final String okulAdi;

  const SchoolExamsListPage({
    super.key,
    required this.okulId,
    required this.okulAdi,
  });

  @override
  State<SchoolExamsListPage> createState() => _SchoolExamsListPageState();
}

class _SchoolExamsListPageState extends State<SchoolExamsListPage> {
  final _api = ApiService();
  final _searchController = TextEditingController();

  List<dynamic> _allExams = [];
  List<dynamic> _filteredExams = [];
  bool _loading = true;
  String? _error;
  String _selectedSubjectFilter = 'Tümü';
  Set<String> _availableSubjects = {'Tümü'};
  String _sortBy = 'Tarih (Yeni)'; // Tarih (Yeni), Tarih (Eski), İsim (A-Z), İsim (Z-A)

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final exams = await _api.getSchoolExams(widget.okulId);
      setState(() {
        _allExams = exams;
        _filteredExams = exams;
        _loading = false;

        // Ders filtresi için mevcut dersleri topla
        _availableSubjects = {'Tümü'};
        for (var exam in exams) {
          final dersAdi = exam['ders_adi'];
          if (dersAdi != null && dersAdi.toString().isNotEmpty) {
            _availableSubjects.add(dersAdi.toString());
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filterExams() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredExams = _allExams.where((exam) {
        final sinavAdi = (exam['ad'] ?? '').toString().toLowerCase();
        final dersAdi = (exam['ders_adi'] ?? '').toString().toLowerCase();
        final tarih = (exam['tarih'] ?? '').toString().toLowerCase();

        // Arama filtresi
        final matchesSearch = query.isEmpty ||
            sinavAdi.contains(query) ||
            dersAdi.contains(query) ||
            tarih.contains(query);

        // Ders filtresi
        final matchesSubject = _selectedSubjectFilter == 'Tümü' ||
            dersAdi == _selectedSubjectFilter.toLowerCase();

        return matchesSearch && matchesSubject;
      }).toList();

      // Sıralama
      _sortExams();
    });
  }

  void _sortExams() {
    switch (_sortBy) {
      case 'Tarih (Yeni)':
        _filteredExams.sort((a, b) {
          final dateA = DateTime.tryParse(a['tarih'] ?? '') ?? DateTime(1900);
          final dateB = DateTime.tryParse(b['tarih'] ?? '') ?? DateTime(1900);
          return dateB.compareTo(dateA); // Yeniden eskiye
        });
        break;
      case 'Tarih (Eski)':
        _filteredExams.sort((a, b) {
          final dateA = DateTime.tryParse(a['tarih'] ?? '') ?? DateTime(1900);
          final dateB = DateTime.tryParse(b['tarih'] ?? '') ?? DateTime(1900);
          return dateA.compareTo(dateB); // Eskiden yeniye
        });
        break;
      case 'İsim (A-Z)':
        _filteredExams.sort((a, b) {
          final nameA = (a['ad'] ?? '').toString().toLowerCase();
          final nameB = (b['ad'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;
      case 'İsim (Z-A)':
        _filteredExams.sort((a, b) {
          final nameA = (a['ad'] ?? '').toString().toLowerCase();
          final nameB = (b['ad'] ?? '').toString().toLowerCase();
          return nameB.compareTo(nameA);
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
        title: Text("${widget.okulAdi} - Sınavlar"),
        actions: [
          // Dashboard butonu
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Dashboard',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SchoolDashboardPage(
                    okulId: widget.okulId,
                    okulAdi: widget.okulAdi,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Sınav adı, ders veya tarih ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterExams();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              onChanged: (value) => _filterExams(),
            ),
          ),

          // Ders filtresi ve Sıralama
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Ders filtresi
                if (_availableSubjects.length > 1)
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _availableSubjects.map((subject) {
                          final isSelected = _selectedSubjectFilter == subject;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(subject),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedSubjectFilter = subject;
                                  _filterExams();
                                });
                              },
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              selectedColor: theme.colorScheme.primaryContainer,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                // Sıralama dropdown
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort, color: theme.colorScheme.primary),
                  tooltip: 'Sırala',
                  onSelected: (value) {
                    setState(() {
                      _sortBy = value;
                      _filterExams();
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'Tarih (Yeni)',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'Tarih (Yeni)'
                                ? Icons.check
                                : Icons.calendar_today,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('Tarih (Yeni)'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Tarih (Eski)',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'Tarih (Eski)'
                                ? Icons.check
                                : Icons.calendar_today,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('Tarih (Eski)'),
                        ],
                      ),
                    ),
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
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Sınav listesi
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
                            Text(
                              "Hata: $_error",
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadExams,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Yeniden Dene'),
                            ),
                          ],
                        ),
                      )
                    : _filteredExams.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.quiz_outlined,
                                  size: 80,
                                  color: theme.colorScheme.primary.withAlpha(100),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty &&
                                          _selectedSubjectFilter == 'Tümü'
                                      ? 'Bu okul için henüz sınav sonucu yok'
                                      : 'Arama sonucu bulunamadı',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color:
                                        theme.colorScheme.onSurface.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadExams,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredExams.length,
                              itemBuilder: (context, index) {
                                final sinav = _filteredExams[index];
                                final sinavId = sinav["id"];
                                final sinavAdi = sinav["ad"] ?? "İsimsiz Sınav";
                                final dersAdi = sinav["ders_adi"] ?? "";
                                final tarih = sinav["tarih"] ?? "";

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
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
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // Delete button (leftmost, red)
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 20),
                                            color: Colors.red,
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Sınavı Sil'),
                                                  content: Text(
                                                      '"$sinavAdi" sınavını silmek istediğinize emin misiniz?'),
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
                                                  // API call to delete exam
                                                  await _api.deleteExam(sinavId);

                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            '"$sinavAdi" sınavı silindi'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );

                                                    // Listeyi yenile
                                                    _loadExams();
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content:
                                                            Text('Hata: ${e.toString()}'),
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
                                              final nameController = TextEditingController(text: sinavAdi);
                                              final dateController = TextEditingController(text: tarih);

                                              final result = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Sınavı Düzenle'),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      TextField(
                                                        controller: nameController,
                                                        decoration: const InputDecoration(
                                                          labelText: 'Sınav Adı',
                                                          border: OutlineInputBorder(),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 16),
                                                      TextField(
                                                        controller: dateController,
                                                        decoration: const InputDecoration(
                                                          labelText: 'Tarih (YYYY-MM-DD)',
                                                          border: OutlineInputBorder(),
                                                          hintText: '2024-01-15',
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
                                                  await _api.updateExam(
                                                    sinavId,
                                                    ad: nameController.text,
                                                    tarih: dateController.text.isNotEmpty ? dateController.text : null,
                                                    donem: sinav['donem'],
                                                    dersId: sinav['ders_id'],
                                                    sinifId: sinav['sinif_id'],
                                                  );

                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('"${nameController.text}" sınavı güncellendi'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );

                                                    _loadExams();
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

                                              nameController.dispose();
                                              dateController.dispose();
                                            },
                                            tooltip: 'Düzenle',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 12),

                                          // ID Badge
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                sinavId.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Content
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sinavAdi,
                                                  style: theme.textTheme.titleLarge
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 8),
                                                if (tarih.isNotEmpty)
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.calendar_today,
                                                        size: 16,
                                                        color:
                                                            theme.colorScheme.primary,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        "Tarih: $tarih",
                                                        style: theme
                                                            .textTheme.bodyMedium
                                                            ?.copyWith(
                                                          color: theme
                                                              .colorScheme.primary,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                if (dersAdi.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Ders: $dersAdi",
                                                    style: theme.textTheme.bodyMedium
                                                        ?.copyWith(
                                                      color: theme.colorScheme.onSurface
                                                          .withAlpha(180),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 20,
                                            color: theme.colorScheme.onSurface
                                                .withAlpha(100),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
