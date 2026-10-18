// lib/pages/classrooms_page.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:typed_data';

import '../services/api_service.dart';
import 'students_page.dart';
import 'admin/import_pdf_exam_page.dart';

class ClassroomsPage extends StatefulWidget {
  final int okulId;
  final String okulAdi;

  const ClassroomsPage({
    super.key,
    required this.okulId,
    required this.okulAdi,
  });

  @override
  State<ClassroomsPage> createState() => _ClassroomsPageState();
}

class _ClassroomsPageState extends State<ClassroomsPage> {
  final _api = ApiService();
  final _searchController = TextEditingController();

  List<dynamic> _allClasses = [];
  List<dynamic> _filteredClasses = [];
  int? _selectedSeviyeFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final classes = await _api.getClassroomsBySchool(widget.okulId);
      setState(() {
        _allClasses = classes;
        _filteredClasses = classes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filterClasses() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClasses = _allClasses.where((sinif) {
        final ad = (sinif['ad'] ?? '').toString().toLowerCase();
        final seviye = sinif['seviye'];

        final matchesSearch = ad.contains(query);
        final matchesSeviye = _selectedSeviyeFilter == null || seviye == _selectedSeviyeFilter;

        return matchesSearch && matchesSeviye;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showImportDialog() async {
    // 1. Format seçimi (Excel veya PDF)
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dosya Formatı Seçin'),
        content: const Text('Öğrenci listesini hangi formatta yüklemek istiyorsunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'excel'),
            icon: const Icon(Icons.table_chart),
            label: const Text('Excel (.xlsx)'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'pdf'),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF (TEK Yayınları)'),
          ),
        ],
      ),
    );

    if (format == null) return;

    // 2. Sınıf seviyesi seçimi (1-8)
    final seviye = await showDialog<int>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Sınıf Seviyesi Seçin'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                final level = index + 1;
                return Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, level),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(100),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$level. Sınıf',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (seviye == null) return;

    // 3. Şube seçimi (A-F)
    final sube = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Şube Seçin'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                final letter = String.fromCharCode(65 + index); // A-F
                return Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, letter),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(100),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$seviye-$letter',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (sube == null) return;

    final sinifAdi = '$seviye-$sube';

    // PDF formatı seçildiyse
    if (format == 'pdf') {
      await _importStudentsFromPdf(sinifAdi);
      return;
    }

    // Excel formatı için devam et
    // 4. Format bilgilendirme dialog'u
    final devamEt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dosya Formatı'),
        content: const Text(
          'Sadece .xlsx formatı desteklenmektedir.\n\n'
          'Eğer .xls formatında dosyanız varsa:\n\n'
          '1. Dosyayı Excel\'de açın\n'
          '2. Dosya → Farklı Kaydet\n'
          '3. Dosya türü: "Excel Çalışma Kitabı (*.xlsx)"\n'
          '4. Kaydedin ve tekrar deneyin',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dosya Seç'),
          ),
        ],
      ),
    );

    if (devamEt != true) return;

    // 4. Excel dosyası seçimi (sadece .xlsx formatı desteklenir)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true, // Web için gerekli
    );

    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dosya seçilmedi')));
      }
      return;
    }

    final platformFile = result.files.single;
    if (platformFile.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dosya okunamadı'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // Dosya uzantısını kontrol et
    if (!platformFile.name.toLowerCase().endsWith('.xlsx')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen .xlsx formatında bir dosya seçin'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // 4. Excel dosyasını oku ve şubeye göre filtrele
    if (mounted) {
      _processExcelFile(platformFile.bytes!, seviye, sube);
    }
  }

  Future<void> _processExcelFile(
    Uint8List fileBytes,
    int seviye,
    String sube,
  ) async {
    try {
      // Progress dialog göster
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Excel dosyası işleniyor...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Excel dosyasını oku
      final excel = excel_pkg.Excel.decodeBytes(fileBytes);

      // İlk sheet'i al
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        throw Exception('Excel dosyası boş');
      }

      // Progress dialog'u kapat
      if (mounted) {
        Navigator.pop(context);
      }

      // DEBUG: Toplam satır sayısı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel okundu: ${sheet.rows.length} satır'),
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(Duration(seconds: 2));
      }

      // Header satırını bul (Öğrenci No içeren satır)
      int headerRowIndex = -1;
      for (int i = 0; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        for (var cell in row) {
          final cellText = cell?.value?.toString() ?? '';
          // Türkçe karakterlerle esnek arama
          if (cellText.toLowerCase().contains('renci') &&
              cellText.toLowerCase().contains('no')) {
            headerRowIndex = i;
            break;
          }
        }
        if (headerRowIndex != -1) break;
      }

      if (headerRowIndex == -1) {
        throw Exception('Excel içinde "Öğrenci No" başlığı bulunamadı');
      }

      // Header sütunlarını al
      final headers = sheet.rows[headerRowIndex];

      // Esnek sütun arama fonksiyonu - İLK VERİ SATIRINA BAKARAK BUL
      // Header'larda merged cell olabilir, o yüzden gerçek verilere bakıyoruz
      int numColIndex = -1;
      int nameColIndex = -1;
      int surnameColIndex = -1;
      int classColIndex = -1;

      // İlk veri satırını bul (header + 1)
      if (headerRowIndex + 1 < sheet.rows.length) {
        final firstDataRow = sheet.rows[headerRowIndex + 1];

        // Her sütunu tara ve dolu olanları bul
        for (int i = 0; i < firstDataRow.length; i++) {
          final cellValue = firstDataRow[i]?.value;
          final headerValue = i < headers.length
              ? headers[i]?.value?.toString().toLowerCase() ?? ''
              : '';

          // Numara sütunu: sayı olan ve header'da "no" içeren
          if (cellValue is int && headerValue.contains('no') && numColIndex == -1) {
            numColIndex = i;
          }
          // Ad sütunu: TextCellValue veya SharedString (isim içeren)
          else if (cellValue is excel_pkg.TextCellValue || cellValue is excel_pkg.SharedString) {
            if (nameColIndex == -1) {
              nameColIndex = i;
            } else if (surnameColIndex == -1) {
              surnameColIndex = i;
            }
          }
        }
      }

      // Yedek: header'lardan bul (eski yöntem)
      if (numColIndex == -1 || nameColIndex == -1 || surnameColIndex == -1) {
        int findColumn(List<String> keywords) {
          for (int i = 0; i < headers.length; i++) {
            final cellText = headers[i]?.value?.toString().toLowerCase() ?? '';
            for (var keyword in keywords) {
              if (cellText.contains(keyword.toLowerCase())) {
                return i;
              }
            }
          }
          return -1;
        }

        if (numColIndex == -1)
          numColIndex = findColumn(['öğrenci no', 'ogrenci no', 'renci no']);
        if (nameColIndex == -1) nameColIndex = findColumn(['adı', 'adi', 'ad']);
        if (surnameColIndex == -1)
          surnameColIndex = findColumn(['soyadı', 'soyadi', 'soyad']);
        classColIndex = findColumn(['sınıf', 'sinif', 'class']);
      }

      // DEBUG: Sütun indekslerini göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sütunlar: Numara=$numColIndex, Ad=$nameColIndex, Soyad=$surnameColIndex',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(Duration(seconds: 3));
      }

      if (numColIndex == -1 || nameColIndex == -1 || surnameColIndex == -1) {
        throw Exception(
          'Gerekli sütunlar bulunamadı (Öğrenci No, Adı, Soyadı)',
        );
      }

      // Öğrencileri filtrele ve topla
      final ogrenciler = <Map<String, dynamic>>[];
      final targetClass = '$seviye-$sube'; // Örn: "8-A"

      int satir_sayisi = 0;
      int bos_satir = 0;
      int gecersiz_numara = 0;
      int bos_ad_soyad = 0;

      for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        satir_sayisi++;

        // Boş satırları atla
        if (row.isEmpty || row.every((cell) => cell?.value == null)) {
          bos_satir++;
          continue;
        }

        // Sınıf kontrolü (eğer sınıf sütunu varsa ve dolu ise)
        if (classColIndex != -1 && classColIndex < row.length) {
          final sinifValue = row[classColIndex]?.value?.toString().trim() ?? '';
          // Sınıf değeri varsa ve hedef sınıfla eşleşmiyorsa atla
          if (sinifValue.isNotEmpty && !sinifValue.contains(targetClass)) {
            continue;
          }
        }
        // NOT: Sınıf sütunu yoksa veya boşsa, tüm satırları al (dosya zaten tek sınıf için)

        final numara = row.length > numColIndex
            ? row[numColIndex]?.value?.toString().trim()
            : null;
        final ad = row.length > nameColIndex
            ? row[nameColIndex]?.value?.toString().trim()
            : null;
        final soyad = row.length > surnameColIndex
            ? row[surnameColIndex]?.value?.toString().trim()
            : null;

        if (numara != null &&
            ad != null &&
            soyad != null &&
            numara.isNotEmpty &&
            ad.isNotEmpty &&
            soyad.isNotEmpty) {
          // Numarayı parse et
          final parsedNumara = int.tryParse(numara);
          if (parsedNumara != null) {
            ogrenciler.add({'numara': parsedNumara, 'ad': ad, 'soyad': soyad});
          } else {
            gecersiz_numara++;
          }
        } else {
          bos_ad_soyad++;
        }
      }

      // DEBUG: İstatistikler
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Taranan: $satir_sayisi, Boş: $bos_satir, Geçersiz numara: $gecersiz_numara, Boş ad/soyad: $bos_ad_soyad, Bulundu: ${ogrenciler.length}',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        await Future.delayed(Duration(seconds: 5));
      }

      if (ogrenciler.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$targetClass sınıfı için öğrenci bulunamadı'),
            ),
          );
        }
        return;
      }

      // Kullanıcıya kaç öğrenci bulunduğunu göster ve onay al
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Onay'),
          content: Text(
            '$targetClass sınıfı için ${ogrenciler.length} öğrenci bulundu.\n\n'
            'Bu öğrencileri sisteme eklemek istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ekle'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Backend'e gönder
      // Önce bu sınıf için sınıf kaydı bul veya oluştur
      await _uploadStudentsToBackend(seviye, sube, ogrenciler);
    } catch (e) {
      // Progress dialog'u kapat (eğer açıksa)
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _uploadStudentsToBackend(
    int seviye,
    String sube,
    List<Map<String, dynamic>> ogrenciler,
  ) async {
    try {
      // Progress dialog göster
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Öğrenciler sisteme ekleniyor...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final sinifAdi = '$seviye-$sube';

      // 1. Önce bu sınıf var mı kontrol et
      final siniflar = await _api.getClassroomsBySchool(widget.okulId);
      Map<String, dynamic>? mevcutSinif;

      for (var sinif in siniflar) {
        if (sinif['ad'] == sinifAdi) {
          mevcutSinif = sinif;
          break;
        }
      }

      // 2. Sınıf yoksa oluştur
      int sinifId;
      if (mevcutSinif == null) {
        final yeniSinif = await _api.createClassroom(
          okulId: widget.okulId,
          ad: sinifAdi,
          seviye: seviye,
        );
        sinifId = yeniSinif['id'];
      } else {
        sinifId = mevcutSinif['id'];
      }

      // 3. Öğrencileri tek tek ekle
      int basariliSayisi = 0;
      int hataliSayisi = 0;

      String? ilkHata;
      for (var ogrenci in ogrenciler) {
        try {
          await _api.addStudent(
            sinifId: sinifId,
            ad: ogrenci['ad'],
            soyad: ogrenci['soyad'],
            numara: ogrenci['numara'],
          );
          basariliSayisi++;
        } catch (e) {
          hataliSayisi++;
          if (ilkHata == null) {
            ilkHata = e.toString();
          }
        }
      }

      // Progress dialog'u kapat
      if (mounted) {
        Navigator.pop(context);
      }

      // Sonuç mesajı göster
      if (mounted) {
        final mesaj = hataliSayisi == 0
            ? '$basariliSayisi öğrenci başarıyla eklendi!'
            : '$basariliSayisi öğrenci eklendi, $hataliSayisi öğrenci eklenemedi.\n\nHata: $ilkHata';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mesaj),
            backgroundColor: hataliSayisi == 0 ? Colors.green : Colors.orange,
            duration: Duration(seconds: 10),
          ),
        );

        // Sınıf listesini yenile
        _loadClasses();
      }
    } catch (e) {
      // Progress dialog'u kapat (eğer açıksa)
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importStudentsFromPdf(String sinifAdi) async {
    // PDF dosya seçimi
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // Web için gerekli
    );

    if (result == null) return;

    final platformFile = result.files.single;

    // Web uyumlu: bytes'ı direkt al
    if (platformFile.bytes == null) return;

    if (!mounted) return;

    // Progress dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('PDF işleniyor...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // PDF'den öğrencileri içe aktar
      final response = await _api.importStudentsFromPdf(
        fileBytes: platformFile.bytes!,
        filename: platformFile.name,
        okulId: widget.okulId,
        sinifAdi: sinifAdi,
      );

      if (!mounted) return;
      Navigator.pop(context); // Progress dialog'u kapat

      // Sonuç mesajını göster
      final message = '${response['message']}\n\n'
          'Sınıf: ${response['sinif_adi']}\n'
          'Eklenen: ${response['eklenen_ogrenci_sayisi']}\n'
          'Toplam PDF: ${response['toplam_pdf_ogrenci']}';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('İçe Aktarma Tamamlandı'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );

      // Sınıf listesini yenile
      _loadClasses();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Progress dialog'u kapat

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showExamUploadDialog() async {
    // Yeni PDF eşleştirme sayfasına yönlendir
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ImportPdfExamPage(),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.okulAdi} - Sınıflar"),
      ),
      body: Column(
        children: [
          // Arama ve filtre bölümü
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Arama çubuğu
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Sınıf adı ara...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterClasses();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) => _filterClasses(),
                  ),
                ),
                const SizedBox(width: 12),
                // Seviye filtresi
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: _selectedSeviyeFilter,
                    decoration: InputDecoration(
                      labelText: 'Seviye',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Tümü'),
                      ),
                      ...List.generate(8, (index) {
                        final level = index + 1;
                        return DropdownMenuItem<int>(
                          value: level,
                          child: Text('$level. Sınıf'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSeviyeFilter = value;
                      });
                      _filterClasses();
                    },
                  ),
                ),
              ],
            ),
          ),

          // Sınıf listesi
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
                              onPressed: _loadClasses,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Yeniden Dene'),
                            ),
                          ],
                        ),
                      )
                    : _filteredClasses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.class_outlined,
                                  size: 80,
                                  color: theme.colorScheme.primary.withAlpha(100),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty &&
                                          _selectedSeviyeFilter == null
                                      ? 'Bu okulda henüz sınıf yok'
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
                            itemCount: _filteredClasses.length,
                            itemBuilder: (context, index) {
                              final sinif = _filteredClasses[index];
                              final sinifId = sinif["id"];
                              final ad = sinif["ad"] ?? "İsimsiz sınıf";
                              final seviye = sinif["seviye"]?.toString() ?? "";

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
                                              title: const Text('Sınıfı Sil'),
                                              content: Text(
                                                  '"$ad" sınıfını silmek istediğinize emin misiniz?'),
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
                                            // TODO: API call to delete class
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Sınıf silme özelliği yakında eklenecek')),
                                            );
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
                                        onPressed: () {
                                          // TODO: Edit class dialog
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Sınıf düzenleme özelliği yakında eklenecek')),
                                          );
                                        },
                                        tooltip: 'Düzenle',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    ad,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: seviye.isNotEmpty
                                      ? Text("Sınıf Seviyesi: $seviye")
                                      : null,
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 20,
                                    color: theme.colorScheme.onSurface.withAlpha(100),
                                  ),
                                  onTap: sinifId == null
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => StudentsPage(
                                                  sinifId: sinifId, sinifAdi: ad),
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
      floatingActionButton: Stack(
        children: [
          Positioned(
            left: 30,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _showExamUploadDialog,
              heroTag: 'exam_upload',
              icon: const Icon(Icons.upload_file),
              label: const Text('Sınav Sonucu'),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _showImportDialog,
              heroTag: 'student_import',
              tooltip: 'Excel\'den Öğrenci Ekle (.xlsx)',
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
