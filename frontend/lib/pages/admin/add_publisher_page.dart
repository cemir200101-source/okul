// lib/pages/admin/add_publisher_page.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AddPublisherPage extends StatefulWidget {
  const AddPublisherPage({super.key});

  @override
  State<AddPublisherPage> createState() => _AddPublisherPageState();
}

class _AddPublisherPageState extends State<AddPublisherPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  final _api = ApiService();
  bool _loading = false;

  Future<void> _createPublisher() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _api.createPublisher(
        ad: _nameController.text,
        kod: _codeController.text.isEmpty ? null : _codeController.text.toUpperCase(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yayınevi başarıyla oluşturuldu!'),
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
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Yayınevi Ekle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bilgilendirme kartı
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sınav sonuçlarını yüklerken yayınevi seçimi yapabilmek için yayınevi ekleyin.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Yayınevi Adı
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Yayınevi Adı *',
                  hintText: 'Örn: TEK Yayınları',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Yayınevi adı gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Yayınevi Kodu
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Yayınevi Kodu (Opsiyonel)',
                  hintText: 'Örn: TEK',
                  prefixIcon: const Icon(Icons.code),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Kodlar otomatik olarak büyük harfe çevrilir',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 32),

              // Kaydet Butonu
              FilledButton.icon(
                onPressed: _loading ? null : _createPublisher,
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
                label: Text(_loading ? 'Kaydediliyor...' : 'Yayınevi Oluştur'),
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
