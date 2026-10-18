// lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_helper.dart';
import '../services/theme_service.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = ApiService();

  String _userName = '';
  String _userRole = '';
  Map<String, dynamic>? _dashboardStats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await _api.getDashboardStats();
      setState(() {
        _dashboardStats = stats;
        _loadingStats = false;
      });
    } catch (e) {
      setState(() {
        _loadingStats = false;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    final role = await AuthHelper.getCurrentRole();
    String roleText = '';

    if (role == UserRole.admin) {
      roleText = 'Sistem Yöneticisi';
    } else if (role == UserRole.mudur) {
      roleText = 'Okul Müdürü';
    }

    // TODO: SharedPreferences'dan username al
    setState(() {
      _userName = 'Admin-1'; // Örnek - gerçekte API'den gelecek
      _userRole = roleText;
      // _schoolName = 'Pusula Kitap Kırtasiye'; // Örnek - gelecekte AppBar'da gösterilecek
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              _userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _userRole,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Animasyonlu tema toggle
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: animation,
                  child: child,
                );
              },
              child: Icon(
                themeService.themeMode == ThemeMode.dark
                    ? Icons.wb_sunny
                    : Icons.nightlight_round,
                key: ValueKey(themeService.themeMode),
              ),
            ),
            onPressed: () => themeService.toggleTheme(),
            tooltip: themeService.themeMode == ThemeMode.dark
                ? 'Aydınlık Mod'
                : 'Karanlık Mod',
          ),
          const SizedBox(width: 8),
          // Profil butonu
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            tooltip: 'Profil',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Bilgilendirme banner'ı (Müdürler için)
          _buildInfoBanner(context),

          // Ana içerik alanı
          Expanded(
            child: _loadingStats
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hoşgeldin başlığı
                        Text(
                          'Dashboard',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Genel bakış ve istatistikler',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // İstatistik kartları
                        if (_dashboardStats != null) _buildStatsCards(theme),
                      ],
                    ),
                  ),
          ),

          // Alt kısım - İstek/Öneri ve Hata Bildirme butonları
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withAlpha(50),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // İstek/Öneri butonu
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: İstek/Öneri formu
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('İstek/Öneri formu yakında eklenecek')),
                      );
                    },
                    icon: const Icon(Icons.lightbulb_outline, size: 20),
                    label: const Text(
                      'İstek, Öneri ve Şikayetlerinizi Bildirin',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Hata bildirme butonu (daha küçük)
                TextButton.icon(
                  onPressed: () {
                    // TODO: Hata bildirme formu
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hata bildirme formu yakında eklenecek')),
                    );
                  },
                  icon: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    'Hata Bildir',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Versiyon 0.608',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(120),
                        fontSize: 11,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '•',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(120),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      'ÇATI DENEME',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(ThemeData theme) {
    return FutureBuilder<UserRole?>(
      future: AuthHelper.getCurrentRole(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final role = snapshot.data!;

        // Admin için istatistikler
        if (role == UserRole.admin) {
          return _buildAdminStats(theme);
        }
        // Müdür için istatistikler
        else if (role == UserRole.mudur) {
          return _buildMudurStats(theme);
        }
        // Öğretmen için istatistikler
        else if (role == UserRole.ogretmen) {
          return _buildOgretmenStats(theme);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAdminStats(ThemeData theme) {
    final stats = _dashboardStats!;

    return Column(
      children: [
        // Üst satır - Toplam sayılar
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Okullar',
                stats['total_schools']?.toString() ?? '0',
                Icons.school,
                theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                theme,
                'Kullanıcılar',
                stats['total_users']?.toString() ?? '0',
                Icons.people,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Alt satır
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Sınıflar',
                stats['total_classes']?.toString() ?? '0',
                Icons.class_,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                theme,
                'Öğrenciler',
                stats['total_students']?.toString() ?? '0',
                Icons.person,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Sınavlar
        _buildStatCard(
          theme,
          'Toplam Sınav',
          stats['total_exams']?.toString() ?? '0',
          Icons.quiz,
          Colors.purple,
        ),

        // Kullanıcı rolleri dağılımı
        if (stats['users_by_role'] != null) ...[
          const SizedBox(height: 24),
          Text(
            'Kullanıcı Dağılımı',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildUserRolesCard(theme, stats['users_by_role']),
        ],
      ],
    );
  }

  Widget _buildMudurStats(ThemeData theme) {
    final stats = _dashboardStats!;

    return Column(
      children: [
        // Okullarım
        _buildStatCard(
          theme,
          'Okullarım',
          stats['my_schools_count']?.toString() ?? '0',
          Icons.school,
          theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Sınıflar',
                stats['total_classes']?.toString() ?? '0',
                Icons.class_,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                theme,
                'Öğrenciler',
                stats['total_students']?.toString() ?? '0',
                Icons.person,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildStatCard(
          theme,
          'Sınavlar',
          stats['total_exams']?.toString() ?? '0',
          Icons.quiz,
          Colors.purple,
        ),

        // Okul listesi
        if (stats['my_schools'] != null && (stats['my_schools'] as List).isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Okullarım',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildSchoolsList(theme, stats['my_schools']),
        ],
      ],
    );
  }

  Widget _buildOgretmenStats(ThemeData theme) {
    final stats = _dashboardStats!;

    return Column(
      children: [
        // Okul adı
        if (stats['school_name'] != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.school, color: theme.colorScheme.primary, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Okulunuz',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                        Text(
                          stats['school_name'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Sınıflar',
                stats['total_classes']?.toString() ?? '0',
                Icons.class_,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                theme,
                'Öğrenciler',
                stats['total_students']?.toString() ?? '0',
                Icons.person,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      color: color.withAlpha(30),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRolesCard(ThemeData theme, Map<String, dynamic> roles) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildRoleRow(theme, 'Admin', roles['admin'] ?? 0, Icons.admin_panel_settings, Colors.red),
            const Divider(),
            _buildRoleRow(theme, 'Müdür', roles['mudur'] ?? 0, Icons.school, Colors.blue),
            const Divider(),
            _buildRoleRow(theme, 'Öğretmen', roles['ogretmen'] ?? 0, Icons.person, Colors.orange),
            const Divider(),
            _buildRoleRow(theme, 'Veli', roles['veli'] ?? 0, Icons.family_restroom, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleRow(ThemeData theme, String label, int count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolsList(ThemeData theme, List<dynamic> schools) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: schools.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final school = schools[index];
          return ListTile(
            leading: Icon(Icons.school, color: theme.colorScheme.primary),
            title: Text(
              school['isim'] ?? 'İsimsiz Okul',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            dense: true,
          );
        },
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<UserRole?>(
      future: AuthHelper.getCurrentRole(),
      builder: (context, snapshot) {
        // Admin için banner gösterme
        if (snapshot.data == UserRole.admin) {
          return const SizedBox.shrink();
        }

        // Müdürler için bilgilendirme
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primaryContainer.withAlpha(200),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withAlpha(50),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Şimdilik sadece burda bilgilendirme mesajları olacak',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
