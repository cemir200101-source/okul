// lib/pages/admin/add_user_page.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedRole = 'mudur';
  int? _selectedOkulId;
  int? _selectedSinifId;
  int? _selectedOgrenciId;
  List<int> _selectedOkulIds = []; // Müdür için birden fazla okul

  final _api = ApiService();
  List<dynamic> _schools = [];
  List<dynamic> _classes = [];
  List<dynamic> _students = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    try {
      final schools = await _api.getSchools();
      setState(() {
        _schools = schools;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Okullar yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _loadClasses(int okulId) async {
    try {
      final classes = await _api.getClassroomsBySchool(okulId);
      setState(() {
        _classes = classes;
        _selectedSinifId = null;
        _selectedOgrenciId = null;
        _students = [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sınıflar yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _loadStudents(int sinifId) async {
    try {
      final students = await _api.getStudentsByClass(sinifId);
      setState(() {
        _students = students;
        _selectedOgrenciId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Öğrenciler yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Rol kontrolü
    if (_selectedRole == 'mudur' && _selectedOkulIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Müdür için en az bir okul seçmelisiniz')),
      );
      return;
    }

    if (_selectedRole == 'ogretmen' && _selectedOkulId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir okul seçin')),
      );
      return;
    }

    if (_selectedRole == 'veli' && _selectedOgrenciId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir öğrenci seçin')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _api.createUser(
        kullaniciAdi: _usernameController.text,
        sifre: _passwordController.text,
        email: _emailController.text,
        rol: _selectedRole,
        okulId: _selectedOkulId,
        ogrenciId: _selectedOgrenciId,
        okulIds: _selectedRole == 'mudur' ? _selectedOkulIds : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı başarıyla oluşturuldu!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Kullanıcı Ekle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kullanıcı Adı
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  hintText: 'Örn: ahmet.yilmaz',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Kullanıcı adı gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Şifre
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  hintText: 'En az 6 karakter',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Şifre gerekli';
                  }
                  if (value.length < 6) {
                    return 'Şifre en az 6 karakter olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // E-posta
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-posta (Opsiyonel)',
                  hintText: 'ornek@email.com',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Rol Seçimi
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kullanıcı Rolü',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'mudur', child: Text('Müdür')),
                          DropdownMenuItem(value: 'ogretmen', child: Text('Öğretmen')),
                          DropdownMenuItem(value: 'veli', child: Text('Veli')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                            // Rol değiştiğinde seçimleri sıfırla
                            _selectedOkulId = null;
                            _selectedSinifId = null;
                            _selectedOgrenciId = null;
                            _selectedOkulIds = [];
                            _classes = [];
                            _students = [];
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Okul Seçimi - Müdür için (çoklu seçim)
              if (_selectedRole == 'mudur')
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Okullar Seçin',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_selectedOkulIds.length} okul',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Okul listesi checkbox'ları
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: _schools.map((school) {
                              final schoolId = school['id'] as int;
                              final schoolName = school['ad'] ?? school['isim'] ?? 'İsimsiz Okul';
                              final isSelected = _selectedOkulIds.contains(schoolId);

                              return CheckboxListTile(
                                title: Text(schoolName),
                                value: isSelected,
                                onChanged: (bool? checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedOkulIds.add(schoolId);
                                    } else {
                                      _selectedOkulIds.remove(schoolId);
                                    }
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Okul Seçimi - Öğretmen için (tekli seçim)
              if (_selectedRole == 'ogretmen')
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Okul Seçin',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _selectedOkulId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          hint: const Text('Okul seçin...'),
                          items: _schools.map((school) {
                            return DropdownMenuItem<int>(
                              value: school['id'],
                              child: Text(school['ad'] ?? school['isim'] ?? 'İsimsiz Okul'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedOkulId = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // Veli için Okul → Sınıf → Öğrenci Seçimi
              if (_selectedRole == 'veli') ...[
                // Okul Seçimi
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Okul Seçin',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _selectedOkulId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            prefixIcon: const Icon(Icons.school),
                          ),
                          hint: const Text('Okul seçin...'),
                          items: _schools.map((school) {
                            return DropdownMenuItem<int>(
                              value: school['id'],
                              child: Text(school['ad'] ?? school['isim'] ?? 'İsimsiz Okul'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedOkulId = value;
                              });
                              _loadClasses(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sınıf Seçimi
                if (_selectedOkulId != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '2. Sınıf Seçin',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _selectedSinifId,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              prefixIcon: const Icon(Icons.class_),
                            ),
                            hint: const Text('Sınıf seçin...'),
                            items: _classes.map((sinif) {
                              return DropdownMenuItem<int>(
                                value: sinif['id'],
                                child: Text(sinif['ad'] ?? 'İsimsiz Sınıf'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedSinifId = value;
                                });
                                _loadStudents(value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_selectedOkulId != null) const SizedBox(height: 16),

                // Öğrenci Seçimi
                if (_selectedSinifId != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3. Öğrenci Seçin',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _selectedOgrenciId,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              prefixIcon: const Icon(Icons.person),
                            ),
                            hint: const Text('Öğrenci seçin...'),
                            items: _students.map((ogrenci) {
                              final ad = ogrenci['ad'] ?? '';
                              final soyad = ogrenci['soyad'] ?? '';
                              final numara = ogrenci['numara']?.toString() ?? '';
                              return DropdownMenuItem<int>(
                                value: ogrenci['id'],
                                child: Text('$ad $soyad ${numara.isNotEmpty ? '($numara)' : ''}'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedOgrenciId = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 32),

              // Kaydet Butonu
              FilledButton.icon(
                onPressed: _loading ? null : _createUser,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_loading ? 'Kaydediliyor...' : 'Kullanıcı Oluştur'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
