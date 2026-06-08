import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/csv_recording_service.dart';
import '../widgets/app_scaffold.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<File> _csvFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFiles();
    });
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final files = await CsvRecordingService.getCsvFiles();
      if (!mounted) return;
      setState(() {
        _csvFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load files: $e')),
      );
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'NetScope Drive Test Export');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete ${file.path.split(Platform.pathSeparator).last}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CsvRecordingService.deleteCsvFile(file.path);
      _loadFiles();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'History',
      subtitle: 'Recorded CSV files',
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _loadFiles,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _csvFiles.isEmpty
              ? const Center(child: Text('No CSV files recorded yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _csvFiles.length,
                  itemBuilder: (context, index) {
                    final file = _csvFiles[index];
                    final filename = file.path.split(Platform.pathSeparator).last;
                    final size = file.existsSync() ? file.lengthSync() : 0;
                    final date = file.existsSync() ? file.lastModifiedSync() : DateTime.now();
                    final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.insert_drive_file),
                        ),
                        title: Text(filename, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('$formattedDate  •  ${_formatSize(size)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share),
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () => _shareFile(file),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              color: Theme.of(context).colorScheme.error,
                              onPressed: () => _deleteFile(file),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
