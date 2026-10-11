import 'package:flutter/material.dart';
import '../../services/photos/photo_upload_settings.dart';

class PhotoUploadSettingsScreen extends StatefulWidget {
  const PhotoUploadSettingsScreen({super.key});
  @override
  State<PhotoUploadSettingsScreen> createState() =>
      _PhotoUploadSettingsScreenState();
}

class _PhotoUploadSettingsScreenState extends State<PhotoUploadSettingsScreen> {
  final _settings = PhotoUploadSettings();
  bool? _enabled;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await _settings.isGeostampEnabled();
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load photo settings.');
    }
  }

  Future<void> _toggle(bool enabled) async {
    setState(() => _saving = true);
    try {
      await _settings.setGeostampEnabled(enabled);
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save photo settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Photo upload settings')),
    body:
        _error != null
            ? Center(
              child: TextButton(onPressed: _load, child: Text('$_error Retry')),
            )
            : _enabled == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Geostamp photos'),
                  subtitle: const Text(
                    'Adds your location to photos taken through EisenVault, in the image and its metadata.',
                  ),
                  value: _enabled!,
                  onChanged: _saving ? null : _toggle,
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Applies to new camera photos only. Document scans and gallery uploads are unchanged. '
                    'Location access is requested when you take a photo. Turning this off does not remove existing camera metadata.',
                  ),
                ),
              ],
            ),
  );
}
