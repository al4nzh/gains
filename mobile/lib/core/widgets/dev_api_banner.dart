import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/config/api_config.dart';
import 'package:gains/core/preferences/dev_api_url_preference.dart';
import 'package:provider/provider.dart';

/// Always-visible debug strip showing the API URL. Tap to change without rebuild.
class DevApiDebugShell extends StatelessWidget {
  const DevApiDebugShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DevApiBanner(),
        Expanded(child: child),
      ],
    );
  }
}

class _DevApiBanner extends StatefulWidget {
  const _DevApiBanner();

  @override
  State<_DevApiBanner> createState() => _DevApiBannerState();
}

class _DevApiBannerState extends State<_DevApiBanner> {
  Future<void> _openEditor() async {
    final client = context.read<ApiClient>();
    final controller = TextEditingController(text: client.baseUrl);
    String? status;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> apply(String url) async {
              final trimmed = url.trim();
              if (trimmed.isEmpty) return;
              await DevApiUrlPreference.save(trimmed);
              client.setBaseUrl(trimmed);
              controller.text = trimmed;
              setSheetState(() => status = 'Saved: $trimmed');
              if (mounted) setState(() {});
            }

            Future<void> test() async {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) return;
              setSheetState(() => status = 'Testing…');
              await DevApiUrlPreference.save(trimmed);
              client.setBaseUrl(trimmed);
              try {
                final response = await client.dio.get<Map<String, dynamic>>(
                  '/health',
                  options: Options(extra: {'skipAuth': true}),
                );
                setSheetState(() => status = 'OK ${response.statusCode}');
                if (mounted) setState(() {});
              } on DioException catch (e) {
                setSheetState(() => status = 'Failed: ${e.message ?? e.type.name}');
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.paddingOf(ctx).bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('API base URL', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(isDense: true),
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => apply(ApiConfig.localUsb),
                        child: const Text('USB'),
                      ),
                      OutlinedButton(
                        onPressed: () => apply(ApiConfig.localWifi),
                        child: const Text('Wi‑Fi'),
                      ),
                      OutlinedButton(
                        onPressed: () => apply(ApiConfig.production),
                        child: const Text('Prod'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: test, child: const Text('Test /health')),
                  if (status != null) ...[
                    const SizedBox(height: 8),
                    Text(status!, style: Theme.of(ctx).textTheme.bodySmall),
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = context.watch<ApiClient>().baseUrl;
    return Material(
      color: Colors.orange.shade900,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: _openEditor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.lan, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'API: $url  (tap to change)',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
