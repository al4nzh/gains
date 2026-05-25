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
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.network(
              PhysiqueApi.imageUrl(scan.imageUrl),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppColors.surface,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, _, _) => Container(
                color: AppColors.surface,
                child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '${scan.estimatedBodyFatPct}%',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
        ),
        Text(
          'Estimated body fat',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Confidence', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(width: 10),
            PhysiqueConfidenceChip(confidence: scan.confidence),
          ],
        ),
        const SizedBox(height: 8),
        Text(dateLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 24),
        const PhysiqueDisclaimerBanner(),
      ],
    );
  }
}
