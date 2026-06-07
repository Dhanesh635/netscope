import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/measurement_repository.dart';
import '../models/measurement_session.dart';
import '../services/export_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/app_scaffold.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MeasurementSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSessions();
    });
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final repository = context.read<MeasurementRepository>();
      final sessions = await repository.getAllSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load sessions: $e')));
    }
  }

  Future<void> _exportSession(MeasurementSession session) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Exporting...')),
    );

    try {
      final exportService = context.read<ExportService>();
      final filePath = await exportService.exportSession(
        session.id,
        share: true,
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Export successful: $filePath')),
      );
    } catch (e) {
      debugPrint('[HistoryScreen] Export failed: $e');
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'History',
      subtitle: 'Previous drive sessions and exports',
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _loadSessions,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? const Center(child: Text('No sessions recorded yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: const Icon(Icons.drive_eta),
                        ),
                        title: Text('Drive Session #${session.id}'),
                        subtitle: Text(formatSessionDateTime(session.startedAt)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _exportSession(session),
                              icon: const Icon(Icons.download),
                              label: const Text('Export CSV'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () async {
                                final repository = context.read<MeasurementRepository>();
                                await repository.deleteSession(session.id);
                                _loadSessions();
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text('Delete Session'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
