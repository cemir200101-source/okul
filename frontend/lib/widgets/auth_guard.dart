// lib/widgets/auth_guard.dart

import 'package:flutter/material.dart';
import '../services/auth_helper.dart';
import '../pages/login_page.dart';

/// Sayfa erişim kontrolü için widget
/// Belirtilen rollere sahip kullanıcıların sayfaya erişmesini sağlar
class AuthGuard extends StatefulWidget {
  final Widget child;
  final List<UserRole> allowedRoles;
  final String? errorMessage;

  const AuthGuard({
    super.key,
    required this.child,
    required this.allowedRoles,
    this.errorMessage,
  });

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isChecking = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final hasPermission = await AuthHelper.hasPermission(widget.allowedRoles);
    setState(() {
      _hasAccess = hasPermission;
      _isChecking = false;
    });

    if (!hasPermission && mounted) {
      // Yetkisiz erişim - login sayfasına yönlendir
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.errorMessage ?? 'Bu sayfaya erişim yetkiniz bulunmamaktadır.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Giriş sayfasına yönlendiriliyorsunuz...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

/// Admin özel widget'i - sadece admin erişebilir
class AdminOnly extends StatelessWidget {
  final Widget child;

  const AdminOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      allowedRoles: const [UserRole.admin],
      errorMessage: 'Bu özellik sadece Admin kullanıcıları içindir.',
      child: child,
    );
  }
}

/// Müdür ve Admin widget'i - müdür ve admin erişebilir
class MudurAndAdmin extends StatelessWidget {
  final Widget child;

  const MudurAndAdmin({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      allowedRoles: const [UserRole.admin, UserRole.mudur],
      errorMessage: 'Bu özellik sadece Müdür ve Admin kullanıcıları içindir.',
      child: child,
    );
  }
}

// TODO: Öğretmen özellikleri eklendiğinde kullanılacak
// /// Öğretmen, Müdür ve Admin widget'i
// class TeacherMudurAndAdmin extends StatelessWidget {
//   final Widget child;
//
//   const TeacherMudurAndAdmin({super.key, required this.child});
//
//   @override
//   Widget build(BuildContext context) {
//     return AuthGuard(
//       allowedRoles: const [UserRole.admin, UserRole.mudur, UserRole.ogretmen],
//       errorMessage: 'Bu özelliğe erişim yetkiniz bulunmamaktadır.',
//       child: child,
//     );
//   }
// }
