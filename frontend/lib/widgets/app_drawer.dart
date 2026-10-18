// lib/widgets/app_drawer.dart

import 'package:flutter/material.dart';
import '../services/auth_helper.dart';
import '../pages/login_page.dart';
import '../pages/home_page.dart';
import '../pages/schools_page.dart';
import '../pages/admin_exams_page.dart';
import '../pages/admin/add_user_page.dart';
import '../pages/admin/add_school_page.dart';
import '../pages/admin/add_publisher_page.dart';
import '../pages/admin/add_classroom_page.dart';
import '../pages/admin/users_page.dart';
import '../pages/admin/import_students_page.dart';
import '../pages/admin/import_exam_results_page.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isAdmin = false;
  bool _adminActionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final isAdmin = await AuthHelper.isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          // Header - Logo ve uygulama adı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Çatı Deneme',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Deneme Analizi',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Menü öğeleri
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.home,
                  title: 'Ana Sayfa',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomePage()),
                    );
                  },
                ),

                const Divider(height: 24, thickness: 1),

                _buildMenuItem(
                  context,
                  icon: Icons.school_outlined,
                  title: 'Okullar',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SchoolsPage()),
                    );
                  },
                ),

                _buildMenuItem(
                  context,
                  icon: Icons.assignment_outlined,
                  title: 'Sınavlar',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminExamsPage()),
                    );
                  },
                ),

                // Kullanıcılar menüsü - Sadece admin görebilir
                if (_isAdmin)
                  _buildMenuItem(
                    context,
                    icon: Icons.people,
                    title: 'Kullanıcılar',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UsersPage()),
                      );
                    },
                  ),

                // Admin Eylemleri - Genişletilebilir menü
                if (_isAdmin) ...[
                  const Divider(height: 24, thickness: 1),

                  ExpansionTile(
                    leading: const Icon(Icons.admin_panel_settings, size: 26),
                    title: const Text(
                      'Admin Eylemleri',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    initiallyExpanded: _adminActionsExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _adminActionsExpanded = expanded;
                      });
                    },
                    children: [
                      _buildSubMenuItem(
                        context,
                        icon: Icons.person_add,
                        title: 'Kullanıcı Ekle',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AddUserPage()),
                          );
                        },
                      ),
                      _buildSubMenuItem(
                        context,
                        icon: Icons.school_outlined,
                        title: 'Okul Ekle',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AddSchoolPage()),
                          );
                        },
                      ),
                      _buildSubMenuItem(
                        context,
                        icon: Icons.book,
                        title: 'Yayınevi Ekle',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AddPublisherPage()),
                          );
                        },
                      ),
                      _buildSubMenuItem(
                        context,
                        icon: Icons.class_,
                        title: 'Sınıf Oluştur',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AddClassroomPage()),
                          );
                        },
                      ),
                      _buildSubMenuItem(
                        context,
                        icon: Icons.upload_file,
                        title: 'Toplu Öğrenci Ekle',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ImportStudentsPage()),
                          );
                        },
                      ),
                      _buildSubMenuItem(
                        context,
                        icon: Icons.assessment,
                        title: 'Toplu Sınav Sonucu Ekle',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ImportExamResultsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ],

                const Divider(height: 24, thickness: 1),

                _buildMenuItem(
                  context,
                  icon: Icons.logout,
                  title: 'Çıkış Yap',
                  onTap: () async {
                    await AuthHelper.clearAuth();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Footer - Kullanıcı bilgisi ve çıkış
          const Divider(height: 1),
          _buildUserSection(context),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 26),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildSubMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.only(left: 72, right: 24, top: 0, bottom: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildUserSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Versiyon 0.608',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '•',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                fontSize: 11,
              ),
            ),
          ),
          Text(
            'ÇATI DENEME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}
