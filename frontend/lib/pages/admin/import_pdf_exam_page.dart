import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../services/api_service.dart';
import '../pdf_matching_page.dart';

class ImportPdfExamPage extends StatefulWidget {
  const ImportPdfExamPage({super.key});

  @override
  State<ImportPdfExamPage> createState() => _ImportPdfExamPageState();
}

class _ImportPdfExamPageState extends State<ImportPdfExamPage> {
  final _api = ApiService();

  List<dynamic> _schools = [];
  int? _selectedSchoolId;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  bool _loadingSchools = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    setState(() => _loadingSchools = true);

    try {
      final schools = await _api.getSchools();
      setState(() {
        _schools = schools;
        _loadingSchools = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingSchools = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Web için gerekli
      );

      if (result != null) {
        final platformFile = result.files.single;
        setState(() {
          _selectedFileBytes = platformFile.bytes;
          _selectedFileName = platformFile.name;
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

  Future<void> _processAndPreview() async {
    if (_selectedSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir okul seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedFileBytes == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir PDF dosyası seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _processing = true);

    try {
      // Backend'e PDF gönder ve önizleme al
      final matchingData = await _api.previewPdfForMatching(
        fileBytes: _selectedFileBytes!,
        filename: _selectedFileName!,
        okulId: _selectedSchoolId!,
      );

      if (mounted) {
        setState(() => _processing = false);

        // Eşleştirme sayfasına git
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfMatchingPage(
              okulId: _selectedSchoolId!,
              matchingData: matchingData,
            ),
          ),
        );

        // Başarılı dönüş
        if (result == true) {
          setState(() {
            _selectedFileBytes = null;
            _selectedFileName = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('PDF Sınav İçe Aktar'),
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: _loadingSchools
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Başlık kartı
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.picture_as_pdf,
                                size: 64,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'PDF Sınav Sonuçlarını Yükle',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sınav sonuçlarını PDF olarak yükleyin. Sistem otomatik olarak öğrencileri eşleştirecek.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 1. Adım: Okul seçimi
                      _buildStepCard(
                        theme: theme,
                        stepNumber: '1',
                        title: 'Okul Seçin',
                        icon: Icons.school,
                        child: DropdownButtonFormField<int>(
                          value: _selectedSchoolId,
                          decoration: InputDecoration(
                            hintText: 'Okul seçin...',
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          items: _schools.map((school) {
                            return DropdownMenuItem<int>(
                              value: school['id'],
                              child: Text(school['isim'] ?? 'İsimsiz'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedSchoolId = value);
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 2. Adım: PDF seçimi
                      _buildStepCard(
                        theme: theme,
                        stepNumber: '2',
                        title: 'PDF Dosyası Seçin',
                        icon: Icons.upload_file,
                        child: Column(
                          children: [
                            // Dosya seçme butonu
                            OutlinedButton.icon(
                              onPressed: _pickPdfFile,
                              icon: const Icon(Icons.folder_open, size: 24),
                              label: const Text(
                                'PDF Seç',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 20,
                                ),
                                side: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            // Seçili dosya gösterimi
                            if (_selectedFileName != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Seçili dosya:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _selectedFileName!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _selectedFileBytes = null;
                                          _selectedFileName = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Önizleme butonu
                      SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _processing ? null : _processAndPreview,
                          icon: _processing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.preview, size: 24),
                          label: Text(
                            _processing ? 'İşleniyor...' : 'Önizle ve Eşleştir',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            disabledBackgroundColor: Colors.grey,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bilgi kartı
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Nasıl Çalışır?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoItem('PDF otomatik olarak analiz edilir'),
                            _buildInfoItem('Öğrenciler numara ile eşleştirilir'),
                            _buildInfoItem('Manuel eşleştirme yapabilirsiniz'),
                            _buildInfoItem('Onayladıktan sonra sisteme kaydedilir'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStepCard({
    required ThemeData theme,
    required String stepNumber,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stepNumber,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(icon, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
