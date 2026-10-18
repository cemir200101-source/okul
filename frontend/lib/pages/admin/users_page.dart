// lib/pages/admin/users_page.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _api = ApiService();
  final _searchController = TextEditingController();

  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  String? _selectedRoleFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await _api.getUsers();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final username = (user['kullanici_adi'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final rol = user['rol'] ?? '';

        final matchesSearch = username.contains(query) || email.contains(query);
        final matchesRole = _selectedRoleFilter == null || rol == _selectedRoleFilter;

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> _deleteUser(int userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Sil'),
        content: Text('"$username" kullanıcısını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _api.deleteUser(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kullanıcı başarıyla silindi'),
              backgroundColor: Colors.green,
            ),
          );
          _loadUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> user) async {
    final usernameController = TextEditingController(text: user['kullanici_adi']);
    final emailController = TextEditingController(text: user['email'] ?? '');
    String selectedRole = user['rol'] ?? 'mudur';

    // Okul listesini yükle
    List<dynamic> schools = [];
    try {
      schools = await _api.getSchools();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Okullar yüklenemedi: $e')),
        );
      }
      return;
    }

    // Müdür için okul_ids'yi al
    List<int> selectedOkulIds = [];
    if (user['rol'] == 'mudur' && user['okul_ids'] != null) {
      selectedOkulIds = List<int>.from(user['okul_ids']);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Kullanıcıyı Düzenle'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'mudur', child: Text('Müdür')),
                          DropdownMenuItem(value: 'ogretmen', child: Text('Öğretmen')),
                          DropdownMenuItem(value: 'veli', child: Text('Veli')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedRole = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Müdür ise okul seçimi (çoklu)
                      if (selectedRole == 'mudur') ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Okullar',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: schools.map((school) {
                              final schoolId = school['id'] as int;
                              final schoolName = school['ad'] ?? school['isim'] ?? 'İsimsiz Okul';
                              final isSelected = selectedOkulIds.contains(schoolId);

                              return CheckboxListTile(
                                dense: true,
                                title: Text(schoolName),
                                value: isSelected,
                                onChanged: (bool? checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      selectedOkulIds.add(schoolId);
                                    } else {
                                      selectedOkulIds.remove(schoolId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () async {
                    // Müdür için okul kontrolü
                    if (selectedRole == 'mudur' && selectedOkulIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Müdür için en az bir okul seçmelisiniz'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    try {
                      await _api.updateUser(
                        userId: user['id'],
                        kullaniciAdi: usernameController.text,
                        email: emailController.text,
                        rol: selectedRole,
                        okulIds: selectedRole == 'mudur' ? selectedOkulIds : null,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kullanıcı başarıyla güncellendi'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadUsers();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
      ),
      body: Column(
        children: [
          // Arama ve Filtre Bölümü
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                // Arama Çubuğu
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı adı veya e-posta ara...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterUsers();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  onChanged: (value) => _filterUsers(),
                ),
                const SizedBox(height: 12),

                // Rol Filtresi
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedRoleFilter,
                        decoration: InputDecoration(
                          labelText: 'Rol Filtresi',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tüm Roller')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'mudur', child: Text('Müdür')),
                          DropdownMenuItem(value: 'ogretmen', child: Text('Öğretmen')),
                          DropdownMenuItem(value: 'veli', child: Text('Veli')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRoleFilter = value;
                          });
                          _filterUsers();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Yenile',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Kullanıcı Listesi
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
                            Text('Hata: $_error', style: TextStyle(color: theme.colorScheme.error)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadUsers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Yeniden Dene'),
                            ),
                          ],
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 64, color: theme.colorScheme.primary.withAlpha(100)),
                                const SizedBox(height: 16),
                                Text(
                                  'Kullanıcı bulunamadı',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              final userId = user['id'];
                              final username = user['kullanici_adi'] ?? 'N/A';
                              final email = user['email'] ?? '';
                              final rol = user['rol'] ?? 'N/A';
                              final okulId = user['okul_id'];

                              // Rol badge rengi
                              Color roleColor;
                              switch (rol) {
                                case 'admin':
                                  roleColor = Colors.red;
                                  break;
                                case 'mudur':
                                  roleColor = Colors.blue;
                                  break;
                                case 'ogretmen':
                                  roleColor = Colors.green;
                                  break;
                                case 'veli':
                                  roleColor = Colors.orange;
                                  break;
                                default:
                                  roleColor = Colors.grey;
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor: roleColor.withAlpha(50),
                                    child: Icon(Icons.person, color: roleColor),
                                  ),
                                  title: Text(
                                    username,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (email.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('📧 $email'),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: roleColor.withAlpha(50),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              rol.toUpperCase(),
                                              style: TextStyle(
                                                color: roleColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (okulId != null) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              'Okul ID: $okulId',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        color: theme.colorScheme.primary,
                                        onPressed: () => _showEditDialog(user),
                                        tooltip: 'Düzenle',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        color: Colors.red,
                                        onPressed: () => _deleteUser(userId, username),
                                        tooltip: 'Sil',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
