import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/field_app_widgets.dart';
import '../../core/database/local_sync_queue.dart';
import 'sync_result.dart';
import 'sync_service.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final SyncService _syncService = SyncService();

  LocalSyncSummary? _summary;
  SyncResult? _lastResult;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _syncService.summary();
      final logs = await _syncService.recentLogs(limit: 25);

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _logs = logs;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Sync status load failed: $error');

      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _syncOfflineData() async {
    if (_syncing) return;

    setState(() {
      _syncing = true;
      _error = null;
    });

    try {
      final result = await _syncService.syncOfflineData();
      final summary = await _syncService.summary();
      final logs = await _syncService.recentLogs(limit: 25);

      if (!mounted) return;

      setState(() {
        _lastResult = result;
        _summary = summary;
        _logs = logs;
      });
    } catch (error) {
      debugPrint('Sync offline data failed: $error');

      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Offline Data')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSummary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                _buildSummaryCard(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _syncing ? null : _syncOfflineData,
                    icon: _syncing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      _syncing
                          ? 'Syncing...'
                          : ((_summary?.failed ?? 0) > 0
                                ? 'Retry Failed'
                                : 'Sync Offline Data'),
                    ),
                  ),
                ),
                if (_lastResult != null) ...[
                  const SizedBox(height: 12),
                  _buildResultBanner(_lastResult!),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (_logs.isEmpty)
                  const Text('No sync activity yet.')
                else
                  ..._logs.map(_buildLogTile),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _summary;
    final pending = summary?.pending ?? 0;
    final syncing = summary?.syncing ?? 0;
    final synced = summary?.synced ?? 0;
    final failed = summary?.failed ?? 0;
    final total = pending + syncing + synced + failed;
    final progress = total == 0 ? 1.0 : synced / total;
    final progressPercent = (progress * 100).round();

    return FieldSurface(
      padding: const EdgeInsets.all(12),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.cloud_sync_outlined,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sync in Progress',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _syncing
                            ? 'Please keep the app open'
                            : 'Encrypted local records are ready',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: AppColors.border,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMetric(
                  'Pending Records',
                  pending,
                  Icons.pending_actions,
                  AppColors.amber,
                ),
                _buildMetric(
                  'Successful Sync',
                  synced,
                  Icons.check_circle_outline,
                  AppColors.primary,
                ),
                _buildMetric(
                  'Failed Sync',
                  failed,
                  Icons.error_outline,
                  AppColors.danger,
                ),
                _buildMetric(
                  'Total Records',
                  total,
                  Icons.dataset_outlined,
                  AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FieldInfoRow(
              icon: Icons.schedule,
              label: 'Last Sync',
              value: _formatDate(summary?.lastSyncTime),
              iconColor: AppColors.info,
            ),
            const SizedBox(height: 12),
            const FieldInfoRow(
              icon: Icons.lock_outline,
              label: 'Storage',
              value: 'Encrypted & Secure',
              iconColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, int value, IconData icon, Color color) {
    return SizedBox(
      width: 145,
      child: FieldMetricTile(
        label: label,
        value: value.toString(),
        icon: icon,
        color: color,
      ),
    );
  }

  Widget _buildResultBanner(SyncResult result) {
    return FieldSurface(
      color: result.hasFailures ? AppColors.amberSoft : AppColors.primarySoft,
      borderColor: result.hasFailures
          ? AppColors.amber.withValues(alpha: 0.28)
          : AppColors.primary.withValues(alpha: 0.24),
      child: Text(
        result.summary,
        style: TextStyle(
          color: result.hasFailures ? AppColors.amber : AppColors.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final status = log['status']?.toString();
    final color = _colorForStatus(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FieldSurface(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconForStatus(status), color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log['entity_type']} ${log['operation']}',
                    softWrap: true,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log['message']?.toString() ?? '',
                    softWrap: true,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(DateTime.tryParse('${log['created_at']}')),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForStatus(String? status) {
    switch (status) {
      case 'synced':
        return AppColors.primary;
      case 'failed':
        return AppColors.danger;
      case 'syncing':
        return AppColors.info;
      case 'skipped':
        return AppColors.amber;
      default:
        return AppColors.muted;
    }
  }

  IconData _iconForStatus(String? status) {
    switch (status) {
      case 'synced':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'syncing':
        return Icons.sync;
      case 'skipped':
        return Icons.pause_circle;
      default:
        return Icons.info;
    }
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Never';

    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }
}
