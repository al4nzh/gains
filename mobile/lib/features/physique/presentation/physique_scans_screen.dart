import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/physique/data/physique_api.dart';
import 'package:gains/features/physique/models/physique_scan.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gains/features/physique/presentation/physique_scan_widgets.dart';
import 'package:provider/provider.dart';

class PhysiqueScansScreen extends StatefulWidget {
  const PhysiqueScansScreen({super.key});

  @override
  State<PhysiqueScansScreen> createState() => _PhysiqueScansScreenState();
}

class _PhysiqueScansScreenState extends State<PhysiqueScansScreen> {
  PhysiqueApi? _api;
  final _picker = ImagePicker();

  List<PhysiqueScan> _scans = [];
  String? _error;
  bool _loading = true;
  bool _uploading = false;

  PhysiqueApi get api => _api ??= PhysiqueApi(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await api.listScans();
      if (!mounted) return;
      setState(() {
        _scans = list;
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
        _error = 'Could not load scans';
        _loading = false;
      });
    }
  }

  String _scanErrorMessage(ApiException e) {
    if (e.statusCode == 503) return 'AI is unavailable (server needs OPENAI_API_KEY).';
    return e.message;
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    if (_uploading) return;

    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Analyzing physique…')),
            ],
          ),
        ),
      ),
    );

    try {
      final scan = await api.createScan([file.path]);
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _uploading = false;
        _scans = [scan, ..._scans.where((s) => s.id != scan.id)];
      });
      context.push('/physique-scans/${scan.id}', extra: scan);
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_scanErrorMessage(e))),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload scan')),
      );
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Physique scans'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _showSourcePicker,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('New scan'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _scans.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.35),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null && _scans.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const PhysiqueDisclaimerBanner(),
        const SizedBox(height: 12),
        if (_scans.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Text(
              'No scans yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          )
        else
          ..._scans.map((scan) => _ScanListTile(
                scan: scan,
                onTap: () => context.push('/physique-scans/${scan.id}', extra: scan),
              )),
      ],
    );
  }
}

class _ScanListTile extends StatelessWidget {
  const _ScanListTile({required this.scan, required this.onTap});

  final PhysiqueScan scan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = scan.createdAt.toLocal();
    final dateLabel =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  PhysiqueApi.imageUrl(scan.imageUrl),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 56,
                    height: 56,
                    color: AppColors.surface,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${scan.estimatedBodyFatPct}% body fat',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PhysiqueConfidenceChip(confidence: scan.confidence),
                        const SizedBox(width: 8),
                        Text(
                          dateLabel,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
