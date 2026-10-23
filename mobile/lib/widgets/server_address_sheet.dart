import 'package:flutter/material.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../l10n/l10n.dart';
import 'pill_button.dart';
import 'pill_text_field.dart';

/// Lets an installed APK talk to the PC running the backend: type the PC's
/// Wi-Fi IP, the app checks /api/health and saves it. Returns true when saved.
/// [ping] is swapped in tests.
Future<bool?> showServerAddressSheet(BuildContext context, {Future<bool> Function(String url) ping = ApiClient.ping}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ServerAddressSheet(ping: ping),
  );
}

/// "http://192.168.1.10:5000/api" -> "192.168.1.10:5000", what the field and Settings show.
String serverLabel(String url) => url.replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/api/?$'), '');

class _ServerAddressSheet extends StatefulWidget {
  final Future<bool> Function(String url) ping;

  const _ServerAddressSheet({required this.ping});

  @override
  State<_ServerAddressSheet> createState() => _ServerAddressSheetState();
}

class _ServerAddressSheetState extends State<_ServerAddressSheet> {
  late final _field = TextEditingController(text: serverLabel(ApiClient.instance.baseUrl));
  bool _checking = false;
  String? _error;
  String? _unreachable; // the URL that did not answer, so "Save anyway" can keep it

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final url = ApiConstants.serverUrl(_field.text);
    if (url == null) {
      setState(() => _error = l.serverAddressInvalid);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
      _unreachable = null;
    });
    final ok = await widget.ping(url);
    if (!mounted) return;
    if (ok) return _keep(url);
    setState(() {
      _checking = false;
      _error = l.serverUnreachable;
      _unreachable = url;
    });
  }

  Future<void> _keep(String? url) async {
    await ApiClient.instance.setServer(url);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.l10n.serverSaved;
    Navigator.of(context).pop(true);
    messenger.showSnackBar(SnackBar(content: Text(saved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.dns_rounded, color: AppTheme.primaryDark),
            const SizedBox(width: 10),
            Text(l.serverAddress, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(l.serverAddressHelp, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          PillTextField(
            fieldKey: const Key('server_field'),
            controller: _field,
            label: l.serverAddress,
            hint: '192.168.1.10',
            icon: Icons.lan_rounded,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            errorText: _error,
            enabled: !_checking,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          PillButton(
            key: const Key('server_save'),
            label: _checking ? l.serverChecking : l.serverTestSave,
            leadingIcon: Icons.wifi_tethering_rounded,
            loading: _checking,
            onPressed: _save,
          ),
          Wrap(alignment: WrapAlignment.center, children: [
            if (_unreachable != null)
              TextButton(key: const Key('server_save_anyway'), onPressed: () => _keep(_unreachable), child: Text(l.serverSaveAnyway)),
            if (!ApiClient.instance.usesDefaultServer)
              TextButton(key: const Key('server_reset'), onPressed: _checking ? null : () => _keep(null), child: Text(l.serverReset)),
          ]),
        ],
      ),
    );
  }
}
