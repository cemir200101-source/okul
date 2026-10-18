// lib/pages/admin/import_students_page.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import 'dart:typed_data';

class ImportStudentsPage extends StatefulWidget {
  const ImportStudentsPage({super.key});

  @override
  State<ImportStudentsPage> createState() => _ImportStudentsPageState();
}

class _ImportStudentsPageState extends State<ImportStudentsPage> {
  final _api = ApiService();

  List<dynamic> _schools = [];
  List<dynamic> _classes = [];

  int? _selectedSchoolId;
  int? _selectedClassId;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  bool _replaceExisting = false;

  bool _loadingSchools = true;
  bool _loadingClasses = false;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Okullar yüklenemedi: $e')));
      }
    }
  }

  Future<void> _loadClasses(int schoolId) async {
    setState(() {
      _loadingClasses = true;
      _selectedClassId = null;
      _classes = [];
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sınıflar yüklenemedi: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Dosya seçilemedi: $e')));
      }
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir sınıf seçin'),
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

    setState(() {
      _uploading = true;
      _uploadResult = null;
    });

    try {
      Map<String, dynamic> result;

      // Dosya uzantısına göre farklı API çağrısı yap
      if (_selectedFileName!.toLowerCase().endsWith('.pdf')) {
        // PDF için sınıf adını bul
        final selectedClass = _classes.firstWhere(
          (c) => c['id'] == _selectedClassId,
        );

        result = await _api.importStudentsFromPdf(
          fileBytes: _selectedFileBytes!,
          filename: _selectedFileName!,
          okulId: _selectedSchoolId!,
          sinifAdi: selectedClass['ad'],
        );
      } else {
        // Excel/CSV için
        result = await _api.importStudentsBulk(
          sinifId: _selectedClassId!,
          fileBytes: _selectedFileBytes!,
          filename: _selectedFileName!,
          replace: _replaceExisting,
        );
      }

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
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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
                  'Excel/CSV veya PDF Formatı',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Dosyanız aşağıdaki sütunları içermelidir:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            _buildFormatRow(theme, 'Ad', 'Öğrencinin adı (zorunlu)'),
            _buildFormatRow(theme, 'Soyad', 'Öğrencinin soyadı (zorunlu)'),
            _buildFormatRow(theme, 'Numara', 'Öğrenci numarası (opsiyonel)'),
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
                    'Ad       | Soyad    | Numara\n'
                    'Ahmet    | Yılmaz   | 101\n'
                    'Mehmet   | Demir    | 102\n'
                    'Ayşe     | Kara     | 103',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(200),
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
          Expanded(child: Text(description, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    if (_uploadResult == null) return const SizedBox.shrink();

    final success = _uploadResult!['success'] ?? false;
    final message = _uploadResult!['message'] ?? '';
    final eklenenSayisi = _uploadResult!['eklenen_ogrenci_sayisi'] ?? 0;
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
            _buildStatRow(theme, 'Eklenen Öğrenci', '$eklenenSayisi'),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
      appBar: AppBar(title: const Text('Toplu Öğrenci İçe Aktarma')),
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
                            setState(() {
                              _selectedClassId = value;
                              _uploadResult = null;
                            });
                          },
                  ),

                  const SizedBox(height: 24),

                  // Mevcut öğrencileri sil seçeneği
                  CheckboxListTile(
                    value: _replaceExisting,
                    onChanged: (value) {
                      setState(() {
                        _replaceExisting = value ?? false;
                      });
                    },
                    title: const Text('Mevcut öğrencileri sil ve yeniden ekle'),
                    subtitle: const Text(
                      'Seçilirse, sınıftaki tüm öğrenciler silinir ve dosyadaki öğrenciler eklenir',
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
                      subtitle: const Text('Excel/CSV veya PDF dosyası seçin'),
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
