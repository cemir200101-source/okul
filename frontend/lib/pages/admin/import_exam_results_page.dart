// lib/pages/admin/import_exam_results_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';

class ImportExamResultsPage extends StatefulWidget {
  const ImportExamResultsPage({super.key});

  @override
  State<ImportExamResultsPage> createState() => _ImportExamResultsPageState();
}

class _ImportExamResultsPageState extends State<ImportExamResultsPage> {
  final _api = ApiService();

  List<dynamic> _schools = [];
  List<dynamic> _classes = [];
  List<dynamic> _exams = [];

  int? _selectedSchoolId;
  int? _selectedClassId;
  int? _selectedExamId;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  bool _replaceExisting = false;

  bool _loadingSchools = true;
  bool _loadingClasses = false;
  bool _loadingExams = false;
  bool _uploading = false;

  Map<String, dynamic>? _uploadResult;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    setState(() {
      _loadingSchools = true;
    });

    try {
      final schools = await _api.getSchools();
      setState(() {
        _schools = schools;
        _loadingSchools = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSchools = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Okullar yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _loadClasses(int schoolId) async {
    setState(() {
      _loadingClasses = true;
      _selectedClassId = null;
      _selectedExamId = null;
      _classes = [];
      _exams = [];
    });

    try {
      final classes = await _api.getClassroomsBySchool(schoolId);
      setState(() {
        _classes = classes;
        _loadingClasses = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingClasses = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sınıflar yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _loadExams(int classId) async {
    setState(() {
      _loadingExams = true;
      _selectedExamId = null;
      _exams = [];
    });

    try {
      final exams = await _api.getClassExams(classId);
      setState(() {
        _exams = exams;
        _loadingExams = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingExams = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sınavlar yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf'],
        withData: true, // Web için gerekli
      );

      if (result != null) {
        final platformFile = result.files.single;
        setState(() {
          // Web uyumlu: bytes'ı direkt al
          _selectedFileBytes = platformFile.bytes;
          _selectedFileName = platformFile.name;
          _uploadResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya seçilemedi: $e')),
        );
      }
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedExamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir sınav seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedFileBytes == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir dosya seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // PDF seçilmişse uyarı göster
    if (_selectedFileName!.toLowerCase().endsWith('.pdf')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF dosyaları için "PDF Sınav İçe Aktar" menüsünü kullanın'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _uploadResult = null;
    });

    try {
      final result = await _api.importExamResultsBulk(
        sinavId: _selectedExamId!,
        fileBytes: _selectedFileBytes!,
        filename: _selectedFileName!,
        replace: _replaceExisting,
      );

      setState(() {
        _uploadResult = result;
        _uploading = false;
        // Dosya seçimini sıfırla
        _selectedFileBytes = null;
        _selectedFileName = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Başarıyla yüklendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInstructions(ThemeData theme) {
    return Card(
      color: theme.colorScheme.primaryContainer.withAlpha(50),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Dosya Formatları',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PDF dosyaları için "PDF Sınav İçe Aktar" menüsünü kullanın (öğrenci eşleştirme özelliği ile)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Excel/CSV dosyaları aşağıdaki sütunları içermelidir:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _buildFormatRow(theme, 'Numara', 'Öğrenci numarası (zorunlu)'),
            _buildFormatRow(theme, 'Puan', 'Toplam puan (opsiyonel)'),
            _buildFormatRow(theme, 'Doğru', 'Doğru sayısı (opsiyonel)'),
            _buildFormatRow(theme, 'Yanlış', 'Yanlış sayısı (opsiyonel)'),
            _buildFormatRow(theme, 'Net', 'Net sayısı (opsiyonel)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Örnek:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Numara | Puan  | Doğru | Yanlış | Net\n'
                    '101    | 85.5  | 17    | 3      | 15.5\n'
                    '102    | 92.0  | 19    | 1      | 18.5\n'
                    '103    | 78.0  | 15    | 5      | 13.0',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.tertiary.withAlpha(100),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: theme.colorScheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Not: Puan yoksa Net değeri puan olarak kullanılır. En az bir puan bilgisi olmalıdır.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatRow(ThemeData theme, String column, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              column,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    if (_uploadResult == null) return const SizedBox.shrink();

    final success = _uploadResult!['success'] ?? false;
    final message = _uploadResult!['message'] ?? '';
    final eklenenSayisi = _uploadResult!['eklenen_sonuc_sayisi'] ?? 0;
    final toplamSatir = _uploadResult!['toplam_satir'] ?? 0;
    final hatalar = _uploadResult!['hatalar'] as List?;

    return Card(
      color: success
          ? theme.colorScheme.primaryContainer.withAlpha(50)
          : theme.colorScheme.errorContainer.withAlpha(50),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatRow(theme, 'Eklenen Sonuç', '$eklenenSayisi'),
            _buildStatRow(theme, 'Toplam Satır', '$toplamSatir'),
            if (hatalar != null && hatalar.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Hatalar:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: hatalar.map((hata) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(hata.toString())),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toplu Sınav Sonucu İçe Aktarma'),
      ),
      body: _loadingSchools
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInstructions(theme),
                  const SizedBox(height: 24),

                  // Okul Seçimi
                  Text(
                    'Okul Seçin',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      hintText: 'Okul seçin',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.school),
                    ),
                    items: _schools.map((school) {
                      return DropdownMenuItem<int>(
                        value: school['id'] as int,
                        child: Text(school['isim'] ?? 'İsimsiz Okul'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSchoolId = value;
                        });
                        _loadClasses(value);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Sınıf Seçimi
                  Text(
                    'Sınıf Seçin',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      hintText: _selectedSchoolId == null
                          ? 'Önce okul seçin'
                          : 'Sınıf seçin',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.class_),
                    ),
                    items: _loadingClasses
                        ? []
                        : _classes.map((classroom) {
                            return DropdownMenuItem<int>(
                              value: classroom['id'] as int,
                              child: Text(classroom['ad'] ?? 'İsimsiz Sınıf'),
                            );
                          }).toList(),
                    onChanged: _selectedSchoolId == null
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _selectedClassId = value;
                                _uploadResult = null;
                              });
                              _loadExams(value);
                            }
                          },
                  ),

                  const SizedBox(height: 16),

                  // Sınav Seçimi
                  Text(
                    'Sınav Seçin',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      hintText: _selectedClassId == null
                          ? 'Önce sınıf seçin'
                          : 'Sınav seçin',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.assignment),
                    ),
                    items: _loadingExams
                        ? []
                        : _exams.map((exam) {
                            return DropdownMenuItem<int>(
                              value: exam['id'] as int,
                              child: Text(exam['ad'] ?? 'İsimsiz Sınav'),
                            );
                          }).toList(),
                    onChanged: _selectedClassId == null
                        ? null
                        : (value) {
                            setState(() {
                              _selectedExamId = value;
                              _uploadResult = null;
                            });
                          },
                  ),

                  const SizedBox(height: 24),

                  // Mevcut sonuçları sil seçeneği
                  CheckboxListTile(
                    value: _replaceExisting,
                    onChanged: (value) {
                      setState(() {
                        _replaceExisting = value ?? false;
                      });
                    },
                    title: const Text('Mevcut sonuçları sil ve yeniden ekle'),
                    subtitle: const Text(
                      'Seçilirse, sınavdaki tüm sonuçlar silinir ve Excel\'deki sonuçlar eklenir',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                  const SizedBox(height: 24),

                  // Dosya Seçimi
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.attach_file),
                      title: Text(
                        _selectedFileName ?? 'Dosya Seçilmedi',
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: const Text('Excel veya CSV dosyası seçin'),
                      trailing: FilledButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Dosya Seç'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Yükleme Butonu
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _uploading ? null : _uploadFile,
                      icon: _uploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(_uploading ? 'Yükleniyor...' : 'Yükle'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sonuç Kartı
                  _buildResultCard(theme),
                ],
              ),
            ),
    );
  }
}
