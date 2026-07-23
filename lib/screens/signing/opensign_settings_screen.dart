import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OpenSignSettingsScreen extends StatefulWidget {
  const OpenSignSettingsScreen({super.key});

  @override
  State<OpenSignSettingsScreen> createState() => _OpenSignSettingsScreenState();
}

class _OpenSignSettingsScreenState extends State<OpenSignSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final account =
        Provider.of<AuthStateManager>(context, listen: false).currentAccount;
    _urlController = TextEditingController(text: account?.essBaseUrl ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenSign Settings')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'ESS base URL',
                  hintText: 'https://signing.example.com',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                validator: _validateUrl,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon:
                      _isSaving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final withScheme =
        text.startsWith('http://') || text.startsWith('https://')
            ? text
            : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) {
      return 'Enter a valid ESS base URL.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    var value = _urlController.text.trim();
    if (value.isNotEmpty &&
        !value.startsWith('http://') &&
        !value.startsWith('https://')) {
      value = 'https://$value';
    }

    final success = await Provider.of<AuthStateManager>(
      context,
      listen: false,
    ).updateEssBaseUrl(value.isEmpty ? null : value);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'OpenSign settings saved.'
              : 'OpenSign settings could not be saved.',
        ),
        backgroundColor: success ? EVColors.successGreen : EVColors.errorRed,
      ),
    );
    if (success) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
