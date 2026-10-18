import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PdfMatchingPage extends StatefulWidget {
  final int okulId;
  final Map<String, dynamic> matchingData;

  const PdfMatchingPage({
    super.key,
    required this.okulId,
    required this.matchingData,
  });

  @override
  State<PdfMatchingPage> createState() => _PdfMatchingPageState();
}

class _PdfMatchingPageState extends State<PdfMatchingPage> {
  final _api = ApiService();
  late List<Map<String, dynamic>> _allMatches;
  final Map<String, int?> _manualMappings = {}; // pdf_student_key -> ogrenci_id
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _initializeMatches();
  }

  void _initializeMatches() {
    _allMatches = [];

    // Otomatik eşleşenler
    final matched = widget.matchingData['matched'] as List? ?? [];
    for (var match in matched) {
      final pdfData = match['pdf_data'] as Map<String, dynamic>;
      final dbStudent = match['db_student'] as Map<String, dynamic>;
      final key = _getPdfStudentKey(pdfData);

      _allMatches.add({
        'pdf_data': pdfData,
        'db_student': dbStudent,
        'match_type': 'exact',
        'key': key,
      });

      // Otomatik eşleşmeyi kaydet
      _manualMappings[key] = dbStudent['id'] as int;
    }

    // Benzer eşleşmeler (manuel gerekli)
    final unmatched = widget.matchingData['unmatched'] as List? ?? [];
    for (var unmatch in unmatched) {
      final pdfData = unmatch['pdf_data'] as Map<String, dynamic>;
      final similarStudents = unmatch['similar_students'] as List? ?? [];
      final key = _getPdfStudentKey(pdfData);

      _allMatches.add({
        'pdf_data': pdfData,
        'similar_students': similarStudents,
        'match_type': 'similar',
        'key': key,
      });
    }

    // Yeni öğrenciler
    final newStudents = widget.matchingData['new_students'] as List? ?? [];
    for (var newStudent in newStudents) {
      final pdfData = newStudent['pdf_data'] as Map<String, dynamic>;
      final key = _getPdfStudentKey(pdfData);

      _allMatches.add({
        'pdf_data': pdfData,
        'match_type': 'new',
        'key': key,
      });
    }
  }

  String _getPdfStudentKey(Map<String, dynamic> pdfData) {
    final numara = pdfData['numara']?.toString() ?? '';
    final isim = pdfData['isim']?.toString() ?? '';
    return '$numara-$isim';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchedCount = widget.matchingData['matched_count'] ?? 0;
    final unmatchedCount = widget.matchingData['unmatched_count'] ?? 0;
    final newCount = widget.matchingData['new_students_count'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenci Eşleştirme'),
        elevation: 2,
      ),
      body: Column(
        children: [
          // Üst bilgi kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.matchingData['sinav_adi'] ?? 'Sınav',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sınıf: ${widget.matchingData['sinif_adi']}',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.check_circle,
                      label: 'Eşleşti',
                      count: matchedCount,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      icon: Icons.warning,
                      label: 'Manuel',
                      count: unmatchedCount,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      icon: Icons.add_circle,
                      label: 'Yeni',
                      count: newCount,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Kaydet butonu (küçük, üstte)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveMatchings,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Eşleştirmeleri Kaydet'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: theme.colorScheme.secondary,
                ),
              ),
            ),
          ),

          // Liste
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _allMatches.length,
                itemBuilder: (context, index) {
                  final match = _allMatches[index];
                  return _buildMatchCard(match);
                },
              ),
            ),
          ),

          // Onayla butonu (büyük, altta)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _confirmAndUpload,
                icon: _uploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file, size: 24),
                label: Text(
                  _uploading ? 'Yükleniyor...' : 'Onayla ve PDF\'i Yükle',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  disabledBackgroundColor: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final matchType = match['match_type'] as String;
    final pdfData = match['pdf_data'] as Map<String, dynamic>;
    final key = match['key'] as String;

    Color cardColor;
    IconData iconData;
    String statusText;

    switch (matchType) {
      case 'exact':
        cardColor = Colors.green;
        iconData = Icons.check_circle;
        statusText = 'Otomatik Eşleşti';
        break;
      case 'similar':
        cardColor = Colors.orange;
        iconData = Icons.warning;
        statusText = 'Manuel Eşleştirme Gerekli';
        break;
      case 'new':
        cardColor = Colors.blue;
        iconData = Icons.add_circle;
        statusText = 'Yeni Öğrenci';
        break;
      default:
        cardColor = Colors.grey;
        iconData = Icons.help;
        statusText = 'Bilinmiyor';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Icon(iconData, color: cardColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: cardColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // PDF'deki öğrenci bilgisi
            Text(
              'PDF\'den:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pdfData['isim'] ?? 'İsimsiz',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Numara: ${pdfData['numara'] ?? 'Yok'} | Puan: ${pdfData['lgs_puan'] ?? '-'}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),

            // Eşleşme detayları
            if (matchType == 'exact') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${match['db_student']['ad']} ${match['db_student']['soyad']} (${match['db_student']['numara']})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (matchType == 'similar') ...[
              const SizedBox(height: 12),
              Text(
                'Benzer öğrenciler:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...(match['similar_students'] as List? ?? []).map((student) {
                final isSelected = _manualMappings[key] == student['id'];
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: Colors.orange.withValues(alpha: 0.2),
                  leading: Radio<int>(
                    value: student['id'] as int,
                    groupValue: _manualMappings[key],
                    onChanged: (value) {
                      setState(() {
                        _manualMappings[key] = value;
                      });
                    },
                  ),
                  title: Text('${student['ad']} ${student['soyad']}'),
                  subtitle: Text('Numara: ${student['numara']}'),
                  onTap: () {
                    setState(() {
                      _manualMappings[key] = student['id'] as int;
                    });
                  },
                );
              }).toList(),
            ] else if (matchType == 'new') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu öğrenci veritabanında bulunmuyor. Atlanacak.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _saveMatchings() {
    // TODO: Eşleştirmeleri geçici olarak kaydet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Eşleştirmeler kaydedildi'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _confirmAndUpload() async {
    // Eksik eşleştirme var mı kontrol et
    int unmappedCount = 0;
    for (final match in _allMatches) {
      final matchType = match['match_type'] as String;
      final key = match['key'] as String;

      if (matchType == 'similar' && _manualMappings[key] == null) {
        unmappedCount++;
      }
    }

    if (unmappedCount > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Uyarı'),
          content: Text(
            '$unmappedCount öğrenci henüz eşleştirilmedi. '
            'Bu öğrenciler atlanacak. Devam etmek istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Devam Et'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Backend'e gönder
    setState(() => _uploading = true);

    try {
      // confirmed_matches hazırla (backend formatına göre)
      final confirmedMatches = <Map<String, dynamic>>[];

      for (final match in _allMatches) {
        final key = match['key'] as String;
        final pdfData = match['pdf_data'] as Map<String, dynamic>;
        final ogrenciId = _manualMappings[key];

        // Sadece eşleştirme yapılmış olanları ekle
        if (ogrenciId != null) {
          confirmedMatches.add({
            'pdf_data': pdfData,
            'ogrenci_id': ogrenciId,
          });
        }
      }

      final result = await _api.confirmAndSaveExam(
        sinavAdi: widget.matchingData['sinav_adi'] ?? '',
        sinifId: widget.matchingData['sinif_id'] ?? 0,
        confirmedMatches: confirmedMatches,
      );

      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'PDF başarıyla yüklendi!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
