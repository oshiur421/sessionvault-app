import 'package:material_ui/material_ui.dart';

import '../services/model_download_service.dart';

/// AI Setup popup — first launch only, over the Recorder screen.
///
/// Shows ONLY: "AI Setup" title, ONE overall progress bar with live %,
/// a short status, "Download models", and "Continue" when done.
/// No model names, sizes or details anywhere in this UI.
class AiSetupDialog extends StatefulWidget {
  const AiSetupDialog({super.key});

  @override
  State<AiSetupDialog> createState() => _AiSetupDialogState();
}

class _AiSetupDialogState extends State<AiSetupDialog> {
  double _fraction = 0;
  String _status = 'Not downloaded yet';
  bool _downloading = false;
  bool _done = false;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await for (final p
          in ModelDownloadService.instance.downloadAll()) {
        if (!mounted) return;
        setState(() {
          _fraction = p.fraction;
          _status = p.status;
          _done = p.done;
          if (p.done) _downloading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString();
        _status = 'Download failed — try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_fraction * 100).round();
    return AlertDialog(
      title: const Text('AI Setup',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_status),
              Text('$pct%',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: _fraction),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        if (!_done)
          ElevatedButton.icon(
            onPressed: _downloading ? null : _startDownload,
            icon: const Icon(Icons.download, size: 18),
            label: Text(_downloading ? 'Downloading…' : 'Download models'),
          )
        else
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
      ],
    );
  }
}
