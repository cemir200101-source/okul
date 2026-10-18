// lib/services/auth_helper.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Kullanıcı rolleri
enum UserRole {
  admin,
  mudur,
  ogretmen, // Şu an kullanılmıyor - gelecek için hazır
  veli,
}

/// Platform tipleri
enum AppPlatform {
  desktop,
  mobile,
  web,
}

class AuthHelper {
  /// Mevcut kullanıcının rolünü getir
  static Future<UserRole?> getCurrentRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString('role');

    if (roleStr == null) return null;

    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'mudur':
      case 'müdür':
        return UserRole.mudur;
      case 'ogretmen':
      case 'öğretmen':
        return UserRole.ogretmen;
      case 'veli':
        return UserRole.veli;
      default:
        return null;
    }
  }

  /// Kullanıcının yetkisi var mı kontrol et
  static Future<bool> hasPermission(List<UserRole> allowedRoles) async {
    final currentRole = await getCurrentRole();
    if (currentRole == null) return false;
    return allowedRoles.contains(currentRole);
  }

  /// Admin mi kontrol et
  static Future<bool> isAdmin() async {
    final role = await getCurrentRole();
    return role == UserRole.admin;
  }

  /// Müdür mü kontrol et
  static Future<bool> isMudur() async {
    final role = await getCurrentRole();
    return role == UserRole.mudur;
  }

  /// Veli mi kontrol et
  static Future<bool> isVeli() async {
    final role = await getCurrentRole();
    return role == UserRole.veli;
  }

  // TODO: Öğretmen özellikleri eklendiğinde kullanılacak
  // /// Öğretmen mi kontrol et
  // static Future<bool> isOgretmen() async {
  //   final role = await getCurrentRole();
  //   return role == UserRole.ogretmen;
  // }

  /// Mevcut platformu getir
  static AppPlatform getCurrentPlatform() {
    if (kIsWeb) {
      return AppPlatform.web;
    }

    // Android veya iOS ise mobile
    if (Platform.isAndroid || Platform.isIOS) {
      return AppPlatform.mobile;
    }

    // Windows, macOS, Linux ise desktop
    return AppPlatform.desktop;
  }

  /// Platform kontrolü - Desktop mi?
  static bool isDesktop() {
    return getCurrentPlatform() == AppPlatform.desktop;
  }

  /// Platform kontrolü - Mobile mi?
  static bool isMobile() {
    return getCurrentPlatform() == AppPlatform.mobile;
  }

  /// Platform ve rol bazlı erişim kontrolü
  /// Veli sadece mobilde, Admin/Müdür sadece desktop'ta
  static Future<bool> canAccessPlatform() async {
    final role = await getCurrentRole();
    final platform = getCurrentPlatform();

    if (role == null) return false;

    // Veli sadece mobilde olabilir
    if (role == UserRole.veli) {
      return platform == AppPlatform.mobile;
    }

    // Admin ve Müdür sadece desktop'ta olabilir
    if (role == UserRole.admin || role == UserRole.mudur) {
      return platform == AppPlatform.desktop || platform == AppPlatform.web;
    }

    // TODO: Öğretmen için kontrol eklenecek
    // if (role == UserRole.ogretmen) {
    //   return platform == AppPlatform.desktop || platform == AppPlatform.web;
    // }

    return false;
  }

  /// Kullanıcı bilgilerini temizle (logout)
  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('role');
    await prefs.remove('username');
    await prefs.remove('ogrenci_id');
    await prefs.remove('okul_id');
  }
}
