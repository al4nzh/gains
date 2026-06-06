import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/config/api_config.dart';
import 'package:gains/core/preferences/dev_api_url_preference.dart';
import 'package:provider/provider.dart';

/// Debug login footer: set API URL at runtime and test `/health`.
class DevApiPanel extends StatefulWidget {
  const DevApiPanel({super.key});

  @override
  State<DevApiPanel> createState() => _DevApiPanelState();
}

class _DevApiPanelState extends State<DevApiPanel> {
  late final TextEditingController _urlController;
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: context.read<ApiClient>().baseUrl,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _applyUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _busy = true;
      _status = null;
    });

    await DevApiUrlPreference.save(trimmed);
    if (!mounted) return;
    context.read<ApiClient>().setBaseUrl(trimmed);
    _urlController.text = trimmed;
    setState(() => _busy = false);
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _busy = true;
      _status = 'Testing…';
    });

    await DevApiUrlPreference.save(url);
    final client = context.read<ApiClient>();
    client.setBaseUrl(url);

    try {
      final response = await client.dio.get<Map<String, dynamic>>(
        '/health',
        options: Options(extra: {'skipAuth': true}),
      );
      if (!mounted) return;
      setState(() {
        _status = 'OK ${response.statusCode} — ${client.baseUrl}';
        _busy = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final hint = e.type == DioExceptionType.connectionError
          ? '\nUSB: plug in phone, run adb reverse tcp:8080 tcp:8080'
          : '';
      setState(() {
        _status = 'Failed: ${e.message ?? e.type.name}$hint';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Local API (debug)',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Set URL here — no rebuild. USB: use 127.0.0.1:8080 + adb reverse.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'API base URL',
              isDense: true,
            ),
            autocorrect: false,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _applyUrl(ApiConfig.localUsb),
                child: const Text('USB'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _applyUrl(ApiConfig.androidEmulator),
                child: const Text('Emulator'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _applyUrl(ApiConfig.localWifi),
                child: const Text('Wi‑Fi PC'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _testConnection,
                  child: const Text('Test /health'),
                ),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(
              _status!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _status!.startsWith('OK')
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
