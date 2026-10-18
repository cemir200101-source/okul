// lib/pages/admin_exams_page.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'school_exams_list_page.dart';
import 'school_dashboard_page.dart';

class AdminExamsPage extends StatefulWidget {
  const AdminExamsPage({super.key});

  @override
  State<AdminExamsPage> createState() => _AdminExamsPageState();
}

class _AdminExamsPageState extends State<AdminExamsPage> {
  final _api = ApiService();
  List<dynamic> _schools = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final schools = await _api.getSchools();
      setState(() {
        _schools = schools;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınavlar - Okul Seçin'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hata: $_error',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadSchools,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Yeniden Dene'),
                      ),
                    ],
                  ),
                )
              : _schools.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 64,
                            color: theme.colorScheme.primary.withAlpha(100),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz okul eklenmemiş',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSchools,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _schools.length,
                        itemBuilder: (context, index) {
                          final school = _schools[index];
                          final schoolId = school['id'];
                          final schoolName = school['ad'] ?? 'İsimsiz Okul';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    // Okul seçildi, sınavlarını göster
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SchoolExamsListPage(
                                          okulId: schoolId,
                                          okulAdi: schoolName,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Okul ikonu
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.school,
                                            size: 28,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Okul bilgileri
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                schoolName,
                                                style: theme.textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Okul ID: $schoolId',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: theme.colorScheme.onSurface
                                                      .withAlpha(150),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // İleri ok ikonu
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 20,
                                          color: theme.colorScheme.onSurface
                                              .withAlpha(100),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                // Dashboard butonu
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SchoolDashboardPage(
                                          okulId: schoolId,
                                          okulAdi: schoolName,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.dashboard,
                                          size: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Dashboard\'u Görüntüle',
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
