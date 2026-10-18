import 'dart:io';
import 'package:excel/excel.dart';

void main() async {
  // Test için Excel dosyası yolunu buraya yazın
  print('Excel dosyasının tam yolunu girin:');
  final filePath = stdin.readLineSync() ?? '';

  print('Dosya yolu: $filePath');
  print('Dosya var mı: ${File(filePath).existsSync()}');

  if (!File(filePath).existsSync()) {
    print('HATA: Dosya bulunamadı!');
    return;
  }

  try {
    final bytes = File(filePath).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    print('Sheet sayısı: ${excel.tables.length}');
    print('Sheet isimleri: ${excel.tables.keys.toList()}');

    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) {
      print('HATA: Sheet boş!');
      return;
    }

    print('Toplam satır: ${sheet.rows.length}');

    // Header satırını bul
    int headerRowIndex = -1;
    for (int i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      for (var cell in row) {
        final cellText = cell?.value?.toString() ?? '';
        if (cellText.toLowerCase().contains('renci') &&
            cellText.toLowerCase().contains('no')) {
          headerRowIndex = i;
          print('Header bulundu, satır: $i');
          break;
        }
      }
      if (headerRowIndex != -1) break;
    }

    if (headerRowIndex == -1) {
      print('HATA: Header bulunamadı!');
      return;
    }

    // Header'ı yazdır
    print('\n=== HEADER (Satır $headerRowIndex) ===');
    final headers = sheet.rows[headerRowIndex];
    for (int i = 0; i < headers.length; i++) {
      final val = headers[i]?.value?.toString() ?? '';
      if (val.isNotEmpty) {
        print('Sütun $i: [$val]');
      }
    }

    // Sütunları bul
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

    final numColIndex = findColumn(['öğrenci no', 'ogrenci no', 'renci no']);
    final nameColIndex = findColumn(['adı', 'adi', 'ad']);
    final surnameColIndex = findColumn(['soyadı', 'soyadi', 'soyad']);

    print('\n=== SÜTUN İNDEKSLERİ ===');
    print('Numara sütunu: $numColIndex');
    print('Ad sütunu: $nameColIndex');
    print('Soyad sütunu: $surnameColIndex');

    // Tüm öğrencileri say
    print('\n=== ÖĞRENCİ TARAMA ===');
    int validCount = 0;
    int invalidCount = 0;

    for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];

      if (row.isEmpty || row.every((cell) => cell?.value == null)) {
        continue;
      }

      final numara = row.length > numColIndex ? row[numColIndex]?.value?.toString().trim() : null;
      final ad = row.length > nameColIndex ? row[nameColIndex]?.value?.toString().trim() : null;
      final soyad = row.length > surnameColIndex ? row[surnameColIndex]?.value?.toString().trim() : null;

      if (numara != null && ad != null && soyad != null &&
          numara.isNotEmpty && ad.isNotEmpty && soyad.isNotEmpty) {
        final parsedNumara = int.tryParse(numara);
        if (parsedNumara != null) {
          validCount++;
          if (validCount <= 5) {
            print('Öğrenci $validCount: No=$parsedNumara, Ad=$ad, Soyad=$soyad');
          }
        } else {
          invalidCount++;
          print('GEÇERSİZ numara: $numara (satır $i)');
        }
      } else {
        invalidCount++;
      }
    }

    print('\n=== SONUÇ ===');
    print('Geçerli öğrenci: $validCount');
    print('Geçersiz satır: $invalidCount');

  } catch (e, stackTrace) {
    print('HATA: $e');
    print('Stack trace: $stackTrace');
  }
}
