import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MusicLibraryDialog extends StatefulWidget {
  const MusicLibraryDialog({super.key});

  @override
  State<MusicLibraryDialog> createState() => _MusicLibraryDialogState();
}

class _MusicLibraryDialogState extends State<MusicLibraryDialog> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _tracks = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTracks();
  }

  Future<void> _fetchTracks() async {
    final result = await _api.getMusicLibrary();
    if (mounted) {
      setState(() {
        _loading = false;
        if (result.isSuccess) {
          _tracks = result.data ?? [];
        } else {
          _error = result.error;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.library_music_rounded, color: AppTheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Soundtrack Library',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a copyright-free track to sync with your reel.',
              style: TextStyle(color: AppTheme.textHint, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_error != null)
              Center(child: Text('Error: $_error', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error)))
            else if (_tracks.isEmpty)
              const Center(child: Text('No tracks available in the library yet.'))
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _tracks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = _tracks[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t['title'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${t['genre']} • ${t['mood']}', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, t),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
