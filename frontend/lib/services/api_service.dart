// lib/services/api_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart' as config;

// Custom exception for duplicate exam
class DuplicateExamException implements Exception {
  final String examName;
  final int examId;

  DuplicateExamException(this.examName, this.examId);

  @override
  String toString() => 'Duplicate exam: $examName (ID: $examId)';
}

class ApiService {
  static const String baseUrl = config.baseUrl;

  // Ngrok ve CORS için gerekli header'lar
  Map<String, String> _getCommonHeaders() {
    return {
      'ngrok-skip-browser-warning': 'true',
      'User-Agent': 'Flutter-Web-Client',
    };
  }

  Future<bool> login(String username, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        ..._getCommonHeaders(),
      };
      final response = await http.post(
        url,
        headers: headers,
        body: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body);
      final accessToken = data['access_token'];

      if (accessToken == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("access_token", accessToken);
      await prefs.setString('role', data['role'] ?? '');
      await prefs.setString('username', data['username'] ?? '');

      if (data['ogrenci_id'] != null) {
        await prefs.setInt('ogrenci_id', data['ogrenci_id']);
      }
      if (data['okul_id'] != null) {
        await prefs.setInt('okul_id', data['okul_id']);
      }
      return true;
    } catch (e) {
      // Hata durumunda false döndür
      return false;
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("access_token");
  }

  Future<List<dynamic>> getSchools() async {
    final url = Uri.parse("$baseUrl/okullar/");

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");

    final headers = <String, String>{
      ..._getCommonHeaders(),
    };
    if (token != null) {
      headers["Authorization"] = "Bearer $token";
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception("Okul listesi alınamadı: ${response.statusCode}");
    }
  }

  Future<List<dynamic>> getClassroomsBySchool(int okulId) async {
    final url = Uri.parse("$baseUrl/siniflar/?okul_id=$okulId");

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");

    final headers = <String, String>{};
    if (token != null) {
      headers["Authorization"] = "Bearer $token";
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception("Sınıf listesi alınamadı: ${response.statusCode}");
    }
  }

  Future<List<dynamic>> getStudentsByClass(int sinifId) async {
    final token = await _getToken();

    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/ogrenciler?sinif_id=$sinifId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Öğrenciler alınamadı: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getParentResults() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception("Token bulunamadı (tekrar giriş yapın).");
    }

    final url = Uri.parse('$baseUrl/veli/sonuclarim');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception("Sonuçlar alınamadı: ${response.statusCode}");
    }
  }

  Future<Map<String, dynamic>> createClassroom({
    required int okulId,
    required String ad,
    required int seviye,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception("Token bulunamadı (tekrar giriş yapın).");
    }

    final url = Uri.parse('$baseUrl/siniflar/');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'okul_id': okulId,
        'ad': ad,
        'seviye': seviye,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Sınıf oluşturulamadı: ${response.statusCode} - ${response.body}");
    }
  }

  Future<Map<String, dynamic>> addStudent({
    required int sinifId,
    required String ad,
    required String soyad,
    required int numara,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception("Token bulunamadı (tekrar giriş yapın).");
    }

    final url = Uri.parse('$baseUrl/ogrenciler/');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'sinif_id': sinifId,
        'ad': ad,
        'soyad': soyad,
        'numara': numara,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Öğrenci eklenemedi: ${response.statusCode} - ${response.body}");
    }
  }

  Future<List<dynamic>> getStudentResults(int ogrenciId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception("Token bulunamadı (tekrar giriş yapın).");
    }

    final url = Uri.parse('$baseUrl/sonuclar/ogrenci/$ogrenciId');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception("Öğrenci sonuçları alınamadı: ${response.statusCode}");
    }
  }

  Future<List<dynamic>> getSchoolExams(int okulId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception("Token bulunamadı (tekrar giriş yapın).");
    }

    final url = Uri.parse('$baseUrl/analizler/okul/$okulId/sinavlar');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception("Sınavlar alınamadı: ${response.statusCode}");
    }
  }

  Future<Map<String, dynamic>> getSchoolExamAnalysis(int okulId, int sinavId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception("Token bulunamadı (tekrar giriş yapın).");
    }

    final url = Uri.parse('$baseUrl/analizler/okul/$okulId/sinav/$sinavId');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Analiz alınamadı: ${response.statusCode}");
    }
  }

  Future<Map<String, dynamic>> getSchoolExamClassComparison(int okulId, int sinavId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception("Token bulunamadı (tekrar giriş yapın).");
    }

    final url = Uri.parse('$baseUrl/analizler/okul/$okulId/sinav/$sinavId/sinif-karsilastirma');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Sınıf karşılaştırması alınamadı: ${response.statusCode}");
    }
  }

  Future<List<dynamic>> getClassExams(int sinifId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception("Token bulunamadı (tekrar giriş yapın).");
    }

    final url = Uri.parse('$baseUrl/analizler/sinif/$sinifId/sinavlar');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception("Sınavlar alınamadı: ${response.statusCode}");
    }
  }

  Future<Map<String, dynamic>> getClassExamAnalysis(int sinifId, int sinavId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception("Token bulunamadı (tekrar giriş yapın).");
    }

    final url = Uri.parse('$baseUrl/analizler/sinif/$sinifId/sinav/$sinavId');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Analiz alınamadı: ${response.statusCode}");
    }
  }

  Future<List<dynamic>> getPublishers() async {
    final token = await _getToken();

    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/yayinevleri/');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception("Yayınevi listesi alınamadı: ${response.statusCode}");
    }
  }

  Future<Map<String, dynamic>> uploadExamPdf({
    required Uint8List fileBytes,
    required String filename,
    required int okulId,
    required String sinifAdi,
    required String publisherKod,
    bool overwrite = false,
  }) async {
    final token = await _getToken();

    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    // Endpoint seçimi - publisherKod'a göre
    String endpoint = '';
    if (publisherKod == 'TEK') {
      endpoint = '/pdf/sinav-tek-yukle';
    } else {
      endpoint = '/pdf/sinav-sonucu-yukle';
    }

    final url = Uri.parse('$baseUrl$endpoint?okul_id=$okulId&sinif_adi=$sinifAdi&overwrite=$overwrite');

    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    // Web uyumlu: fromBytes kullan
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 409) {
      // Duplicate exam - throw special exception
      final error = jsonDecode(response.body);
      throw DuplicateExamException(
        error['detail']['sinav_adi'] ?? 'Sınav',
        error['detail']['sinav_id'] ?? 0,
      );
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'PDF yüklenemedi: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> importStudentsFromPdf({
    required Uint8List fileBytes,
    required String filename,
    required int okulId,
    required String sinifAdi,
  }) async {
    final token = await _getToken();

    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/import/pdf/ogrenciler?okul_id=$okulId&sinif_adi=$sinifAdi');

    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    // Web uyumlu: fromBytes kullan
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Öğrenciler içe aktarılamadı: ${response.statusCode}');
    }
  }

  /// PDF önizleme ve eşleştirme - İlk adım
  Future<Map<String, dynamic>> previewPdfForMatching({
    required Uint8List fileBytes,
    required String filename,
    required int okulId,
  }) async {
    final token = await _getToken();

    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/pdf/onizleme?okul_id=$okulId');

    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers.addAll(_getCommonHeaders());

    // Web uyumlu: fromBytes kullan
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'PDF önizlemesi alınamadı: ${response.statusCode}');
    }
  }

  /// PDF eşleştirme onaylama ve kaydetme - İkinci adım
  Future<Map<String, dynamic>> confirmAndSaveExam({
    required String sinavAdi,
    required int sinifId,
    required List<Map<String, dynamic>> confirmedMatches, // [{pdf_data: {...}, ogrenci_id: int}]
  }) async {
    final token = await _getToken();

    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/pdf/onizleme-onayla');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ..._getCommonHeaders(),
      },
      body: jsonEncode({
        'sinav_adi': sinavAdi,
        'sinif_id': sinifId,
        'confirmed_matches': confirmedMatches,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'PDF kaydedilemedi: ${response.statusCode}');
    }
  }

  // ==================== DASHBOARD İŞLEMLERİ ====================

  /// Dashboard istatistiklerini getir
  Future<Map<String, dynamic>> getDashboardStats() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/auth/dashboard/stats');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Dashboard istatistikleri alınamadı: ${response.statusCode}');
    }
  }

  // ==================== PROFİL İŞLEMLERİ ====================

  /// Mevcut kullanıcı bilgilerini getir
  Future<Map<String, dynamic>> getCurrentUserInfo() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/auth/me');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Kullanıcı bilgileri alınamadı: ${response.statusCode}');
    }
  }

  /// Kendi profil bilgilerini güncelle
  Future<Map<String, dynamic>> updateMyProfile({
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/auth/me');
    final body = <String, dynamic>{};

    if (email != null && email.isNotEmpty) {
      body['email'] = email;
    }

    if (currentPassword != null && currentPassword.isNotEmpty &&
        newPassword != null && newPassword.isNotEmpty) {
      body['current_password'] = currentPassword;
      body['new_password'] = newPassword;
    }

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Profil güncellenemedi: ${response.statusCode}');
    }
  }

  // ==================== ADMIN İŞLEMLERİ ====================

  /// Yeni kullanıcı oluşturma (sadece admin)
  Future<Map<String, dynamic>> createUser({
    required String kullaniciAdi,
    required String sifre,
    required String email,
    required String rol,
    int? okulId,
    int? ogrenciId,
    List<int>? okulIds, // Müdür için birden fazla okul
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/auth/register');
    final body = {
      'kullanici_adi': kullaniciAdi,
      'sifre': sifre,
      'email': email,
      'rol': rol,
      'okul_id': okulId,
      'ogrenci_id': ogrenciId,
    };

    // Müdür için okul_ids ekle
    if (okulIds != null && okulIds.isNotEmpty) {
      body['okul_ids'] = okulIds;
    }

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Kullanıcı oluşturulamadı: ${response.statusCode}');
    }
  }

  /// Yeni okul oluşturma (sadece admin)
  Future<Map<String, dynamic>> createSchool({
    required String isim,
    String? sehir,
    String? ilce,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/okullar/');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'isim': isim,
        'sehir': sehir,
        'ilce': ilce,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Okul oluşturulamadı: ${response.statusCode}');
    }
  }

  /// Yeni yayınevi oluşturma
  Future<Map<String, dynamic>> createPublisher({
    required String ad,
    String? kod,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/yayinevleri/');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'ad': ad,
        'kod': kod,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Yayınevi oluşturulamadı: ${response.statusCode}');
    }
  }

  /// Yeni sınıf oluşturma (Admin için)
  Future<Map<String, dynamic>> createClass({
    required String ad,
    required int okulId,
    int? seviye,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/siniflar/');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'ad': ad,
        'okul_id': okulId,
        'seviye': seviye,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Sınıf oluşturulamadı: ${response.statusCode}');
    }
  }

  /// Tüm kullanıcıları listele (sadece admin)
  Future<List<dynamic>> getUsers() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/auth/users');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Kullanıcılar alınamadı: ${response.statusCode}');
    }
  }

  /// Kullanıcı güncelle (sadece admin)
  Future<Map<String, dynamic>> updateUser({
    required int userId,
    String? kullaniciAdi,
    String? email,
    String? rol,
    int? okulId,
    List<int>? okulIds, // Müdür için birden fazla okul
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/auth/users/$userId');
    final body = <String, dynamic>{};

    if (kullaniciAdi != null) body['kullanici_adi'] = kullaniciAdi;
    if (email != null) body['email'] = email;
    if (rol != null) body['rol'] = rol;
    if (okulId != null) body['okul_id'] = okulId;
    if (okulIds != null) body['okul_ids'] = okulIds;

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Kullanıcı güncellenemedi: ${response.statusCode}');
    }
  }

  /// Kullanıcı sil (sadece admin)
  Future<void> deleteUser(int userId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/auth/users/$userId');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Kullanıcı silinemedi: ${response.statusCode}');
    }
  }

  // ==================== TOPLU İÇE AKTARMA ====================

  /// Excel/CSV'den toplu öğrenci içe aktarma
  Future<Map<String, dynamic>> importStudentsBulk({
    required int sinifId,
    required Uint8List fileBytes,
    required String filename,
    bool replace = false,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/import/ogrenciler/excel?sinif_id=$sinifId&replace=$replace');

    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    // Web uyumlu: fromBytes kullan
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Toplu öğrenci içe aktarımı başarısız: ${response.statusCode}');
    }
  }

  /// Excel/CSV'den toplu sınav sonucu içe aktarma
  Future<Map<String, dynamic>> importExamResultsBulk({
    required int sinavId,
    required Uint8List fileBytes,
    required String filename,
    bool replace = false,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/import/sinav-sonuclari/excel?sinav_id=$sinavId&replace=$replace');

    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';

    // Web uyumlu: fromBytes kullan
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Toplu sınav sonucu içe aktarımı başarısız: ${response.statusCode}');
    }
  }

  // ==================== RAPOR DI ŞA AKTARMA ====================

  /// Sınav sonuçlarını Excel formatında indir
  Future<String> exportExamResultsExcel(int sinavId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/exports/sinav-sonuclari/excel?sinav_id=$sinavId');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return url.toString();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Excel export başarısız: ${response.statusCode}');
    }
  }

  /// Sınıf analiz raporunu Excel formatında indir
  Future<String> exportClassAnalysisExcel(int sinifId, int sinavId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/exports/sinif-analiz/excel?sinif_id=$sinifId&sinav_id=$sinavId');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return url.toString();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Excel export başarısız: ${response.statusCode}');
    }
  }

  // ==================== İLERİ SEVİYE ANALİZ ====================

  /// Okul geneli istatistikler
  Future<Map<String, dynamic>> getSchoolStatistics(int okulId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/analizler/okul/$okulId/istatistikler');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'İstatistikler alınamadı: ${response.statusCode}');
    }
  }

  /// Öğrencinin ders bazında performans analizi
  Future<Map<String, dynamic>> getStudentSubjectPerformance(int ogrenciId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/analizler/ogrenci/$ogrenciId/ders-performans');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Ders performansı alınamadı: ${response.statusCode}');
    }
  }

  /// Sınıf başarı trendleri
  Future<Map<String, dynamic>> getClassSuccessTrends(int sinifId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/analizler/sinif/$sinifId/basari-trendleri');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Başarı trendleri alınamadı: ${response.statusCode}');
    }
  }

  // ==================== SINAV YÖNETİMİ ====================

  /// Sınav sil
  Future<Map<String, dynamic>> deleteExam(int sinavId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/sinavlar/$sinavId');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Sınav silinemedi: ${response.statusCode}');
    }
  }

  /// Sınav güncelle
  Future<Map<String, dynamic>> updateExam(
    int sinavId, {
    required String ad,
    String? tarih,
    String? donem,
    int? dersId,
    int? sinifId,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/sinavlar/$sinavId');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'ad': ad,
        'tarih': tarih,
        'donem': donem,
        'ders_id': dersId,
        'sinif_id': sinifId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Sınav güncellenemedi: ${response.statusCode}');
    }
  }

  // ==================== ÖĞRENCİ YÖNETİMİ ====================

  /// Öğrenci sil
  Future<Map<String, dynamic>> deleteStudent(int ogrenciId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/ogrenciler/$ogrenciId');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Öğrenci silinemedi: ${response.statusCode}');
    }
  }

  /// Öğrenci güncelle
  Future<Map<String, dynamic>> updateStudent(
    int ogrenciId, {
    required String ad,
    required String soyad,
    required int numara,
    required int sinifId,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/ogrenciler/$ogrenciId');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'ad': ad,
        'soyad': soyad,
        'numara': numara,
        'sinif_id': sinifId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Öğrenci güncellenemedi: ${response.statusCode}');
    }
  }

  // ==================== OKUL YÖNETİMİ ====================

  /// Okul sil
  Future<Map<String, dynamic>> deleteSchool(int okulId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/okullar/$okulId');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Okul silinemedi: ${response.statusCode}');
    }
  }

  /// Okul güncelle
  Future<Map<String, dynamic>> updateSchool(
    int okulId, {
    required String isim,
    required String sehir,
    required String ilce,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Token bulunamadı, tekrar giriş yap');
    }

    final url = Uri.parse('$baseUrl/okullar/$okulId');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'isim': isim,
        'sehir': sehir,
        'ilce': ilce,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Okul güncellenemedi: ${response.statusCode}');
    }
  }
}
