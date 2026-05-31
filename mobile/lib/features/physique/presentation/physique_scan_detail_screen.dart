import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/physique/data/physique_api.dart';
import 'package:gains/features/physique/models/physique_scan.dart';
import 'package:gains/features/physique/presentation/physique_scan_widgets.dart';
import 'package:provider/provider.dart';

class PhysiqueScanDetailScreen extends StatefulWidget {
  const PhysiqueScanDetailScreen({
    super.key,
    required this.scanId,
    this.initialScan,
  });

  final String scanId;
  final PhysiqueScan? initialScan;

  @override
  State<PhysiqueScanDetailScreen> createState() => _PhysiqueScanDetailScreenState();
}

class _PhysiqueScanDetailScreenState extends State<PhysiqueScanDetailScreen> {
  PhysiqueApi? _api;
  PhysiqueScan? _scan;
  String? _error;
  bool _loading = false;

  PhysiqueApi get api => _api ??= PhysiqueApi(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    _scan = widget.initialScan;
    if (_scan == null) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scan = await api.getScan(widget.scanId);
      if (!mounted) return;
      setState(() {
        _scan = scan;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load scan';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Scan result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _scan == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _scan == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final scan = _scan!;
    final date = scan.createdAt.toLocal();
    final dateLabel =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(
                '${scan.estimatedBodyFatPct}%',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated body fat',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Confidence', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(width: 10),
            PhysiqueConfidenceChip(confidence: scan.confidence),
          ],
        ),
        const SizedBox(height: 8),
        Text(dateLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        if (scan.summary.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Summary',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            scan.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (scan.reasoning.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Reasoning',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            scan.reasoning,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 24),
        const PhysiqueDisclaimerBanner(),
      ],
    );
  }
}
