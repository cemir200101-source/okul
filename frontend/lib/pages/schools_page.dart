// lib/pages/schools_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_helper.dart';
import '../services/theme_service.dart';
import '../widgets/auth_guard.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_footer.dart';
import 'classrooms_page.dart';

class SchoolsPage extends StatefulWidget {
  const SchoolsPage({super.key});

  @override
  State<SchoolsPage> createState() => _SchoolsPageState();
}

class _SchoolsPageState extends State<SchoolsPage> {
  final _api = ApiService();
  final _searchController = TextEditingController();

  List<dynamic> _allSchools = [];
  List<dynamic> _filteredSchools = [];
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchools();
    _checkRole();
  }

  Future<void> _loadSchools() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final schools = await _api.getSchools();
      setState(() {
        _allSchools = schools;
        _filteredSchools = schools;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filterSchools() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSchools = _allSchools.where((school) {
        final name = (school['ad'] ?? school['isim'] ?? '').toString().toLowerCase();
        final city = (school['sehir'] ?? '').toString().toLowerCase();
        final district = (school['ilce'] ?? '').toString().toLowerCase();

        return name.contains(query) || city.contains(query) || district.contains(query);
      }).toList();
    });
  }

  Future<void> _checkRole() async {
    final isAdmin = await AuthHelper.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sadece Admin ve Müdür erişebilir
    return MudurAndAdmin(
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text("Okullar"),
          actions: [
            // Tema değiştirme butonu appbar'da da olsun
            IconButton(
              icon: Icon(
                theme.brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              onPressed: () {
                Provider.of<ThemeService>(context, listen: false).toggleTheme();
              },
              tooltip: 'Tema Değiştir',
            ),
          ],
        ),
        body: Column(
          children: [
            // Bilgi banner'ı - resme göre
            _buildInfoBanner(context),

            // Arama çubuğu
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Okul adı, şehir veya ilçe ara...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterSchools();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                onChanged: (value) => _filterSchools(),
              ),
            ),

            // Okul listesi
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                              const SizedBox(height: 16),
                              Text("Hata: $_error"),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadSchools,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Yeniden Dene'),
                              ),
                            ],
                          ),
                        )
                      : _buildSchoolsList(theme),
            ),
            // Footer
            const AppFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolsList(ThemeData theme) {
    final schools = _filteredSchools;

    if (schools.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 80,
              color: theme.colorScheme.primary.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'Henüz okul bulunmuyor'
                  : 'Arama sonucu bulunamadı',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 8),
            if (_isAdmin && _searchController.text.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Yeni okul ekleme sayfası
                },
                icon: const Icon(Icons.add),
                label: const Text('Yeni Okul Ekle'),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 2.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: schools.length,
      itemBuilder: (context, index) {
        final okul = schools[index];
        final okulId = okul["id"];
        final okulAdi = okul["isim"] ?? "İsimsiz okul";
        final sehir = okul["sehir"] ?? "";
        final ilce = okul["ilce"] ?? "";

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: okulId == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClassroomsPage(
                          okulId: okulId,
                          okulAdi: okulAdi,
                        ),
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Delete button (leftmost, red)
                  if (_isAdmin)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: Colors.red,
                      onPressed: () async {
                        // TODO: Delete confirmation dialog and API call
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Okulu Sil'),
                            content: Text(
                                '"$okulAdi" okulunu silmek istediğinize emin misiniz?'),
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
                          try {
                            // API call to delete school
                            await _api.deleteSchool(okulId);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"$okulAdi" okulu silindi'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Listeyi yenile
                              _loadSchools();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Hata: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      tooltip: 'Sil',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (_isAdmin) const SizedBox(width: 8),

                  // Edit button
                  if (_isAdmin)
                    IconButton(
                      icon: const Icon(Icons.settings, size: 20),
                      color: theme.colorScheme.primary,
                      onPressed: () async {
                        final isimController = TextEditingController(text: okulAdi);
                        final sehirController = TextEditingController(text: sehir);
                        final ilceController = TextEditingController(text: ilce);

                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Okulu Düzenle'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: isimController,
                                  decoration: const InputDecoration(
                                    labelText: 'Okul Adı',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: sehirController,
                                  decoration: const InputDecoration(
                                    labelText: 'Şehir',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: ilceController,
                                  decoration: const InputDecoration(
                                    labelText: 'İlçe',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('İptal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                ),
                                child: const Text('Kaydet'),
                              ),
                            ],
                          ),
                        );

                        if (result == true && mounted) {
                          try {
                            await _api.updateSchool(
                              okulId,
                              isim: isimController.text,
                              sehir: sehirController.text,
                              ilce: ilceController.text,
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${isimController.text}" güncellendi'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              _loadSchools();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Hata: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }

                        isimController.dispose();
                        sehirController.dispose();
                        ilceController.dispose();
                      },
                      tooltip: 'Düzenle',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (_isAdmin) const SizedBox(width: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.school,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          okulAdi,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (sehir.isNotEmpty || ilce.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurface
                                    .withAlpha(150),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "$sehir${sehir.isNotEmpty && ilce.isNotEmpty ? ' / ' : ''}$ilce",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(150),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 20,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final theme = Theme.of(context);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAdmin
                      ? 'İstek, öneri ve şikayetlerinizi lütfen bize bildirin.'
                      : 'Müdürlerin Dikkatine !!!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isAdmin
                      ? 'Sisteme eklememizi istediğiniz bölümleri, yapmamızı istediğiniz değişiklikleri, her türlü eleştirinizi ve şikayetlerinizi lütfen rahatça bize bildirin.'
                      : 'Yeni kurum eklerken kurum isimlerinin düzgün ve anlaşılır bir şekilde oluşturulması gerekmektedir.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
