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
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: const FieldBackButton(),
        title: const Text('Sync Offline Data'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSummary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                _buildSummaryCard(),
                const SizedBox(height: 14),

                // ── Sync action button ─────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _syncing ? null : _syncOfflineData,
                    icon: _syncing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      _syncing
                          ? 'Syncing…'
                          : ((_summary?.failed ?? 0) > 0
                                ? 'Retry Failed Records'
                                : 'Sync Offline Data'),
                    ),
                  ),
                ),

                // ── Last result banner ─────────────────────────────────
                if (_lastResult != null) ...[
                  const SizedBox(height: 12),
                  _buildResultBanner(_lastResult!),
                ],

                // ── Error message ──────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  FieldSurface(
                    color: AppColors.dangerSoft,
                    borderColor: AppColors.danger.withValues(alpha: 0.24),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Recent activity section ────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.history, size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(
                      'Recent Activity',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    const Spacer(),
                    if (_logs.isNotEmpty)
                      Text(
                        '${_logs.length} events',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_logs.isEmpty)
                  FieldSurface(
                    padding: const EdgeInsets.all(24),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.history_toggle_off,
                          size: 36,
                          color: AppColors.muted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No sync activity yet',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
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
                      'Sync Status',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _syncing
                          ? 'Uploading records — keep app open'
                          : 'Encrypted records ready to upload',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppColors.border,
            color: failed > 0 ? AppColors.danger : AppColors.primary,
          ),

          const SizedBox(height: 16),

          // Metrics row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMetric(
                'Pending',
                pending,
                Icons.pending_actions,
                AppColors.amber,
              ),
              _buildMetric(
                'Synced',
                synced,
                Icons.check_circle_outline,
                AppColors.primary,
              ),
              _buildMetric(
                'Failed',
                failed,
                Icons.error_outline,
                AppColors.danger,
              ),
              _buildMetric(
                'Total',
                total,
                Icons.dataset_outlined,
                AppColors.info,
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

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
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            result.hasFailures
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: result.hasFailures ? AppColors.amber : AppColors.primaryDark,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.summary,
              style: TextStyle(
                color: result.hasFailures
                    ? AppColors.amber
                    : AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_iconForStatus(status), color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log['entity_type']} • ${log['operation']}',
                    softWrap: true,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    log['message']?.toString() ?? '',
                    softWrap: true,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_outlined,
                        size: 11,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(DateTime.tryParse('${log['created_at']}')),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status pill
            FieldStatusPill(label: status ?? 'unknown', color: color),
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
