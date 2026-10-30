import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/arr/models/arr_credentials.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/models/qbittorrent_credentials.dart';
import 'package:kinos/arr/providers/arr_providers.dart';
import 'package:kinos/arr/providers/qbittorrent_providers.dart';
import 'package:kinos/arr/services/arr_api_client.dart';
import 'package:kinos/arr/services/qbittorrent_api_client.dart';
import 'package:kinos/arr/widgets/arr_desktop_scope.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/app_page_header.dart';

/// Réglages Radarr et Sonarr — URL, clé API, test de connexion, pour
/// chaque service séparément. Route enfant de l'écran Réglages.
@RoutePage()
class ArrSettingsScreen extends StatelessWidget {
  const ArrSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ArrDesktopScope(
      child: ColoredBox(
        color: AppColors.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppPageHeader(title: 'Radarr et Sonarr'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "URL et clé API de chaque service, pour la recherche interactive. "
                    "Stockées dans le coffre sécurisé de l'appareil, jamais en clair.",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _ArrServiceSettingsCard(service: ArrService.radarr),
                  const SizedBox(height: AppSpacing.lg),
                  const _ArrServiceSettingsCard(service: ArrService.sonarr),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Client de téléchargement',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "qBittorrent — nécessaire pour mettre en pause ou reprendre "
                    "un téléchargement depuis la file d'attente : l'API "
                    "Radarr/Sonarr n'expose pas cette action elle-même. Une "
                    "seule instance, partagée par Radarr et Sonarr.",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _QBittorrentSettingsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrServiceSettingsCard extends ConsumerStatefulWidget {
  final ArrService service;

  const _ArrServiceSettingsCard({required this.service});

  @override
  ConsumerState<_ArrServiceSettingsCard> createState() =>
      _ArrServiceSettingsCardState();
}

class _ArrServiceSettingsCardState
    extends ConsumerState<_ArrServiceSettingsCard> {
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _seeded = false;
  bool _testing = false;
  ArrConnectionResult? _testResult;
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _seed(ArrCredentials credentials) {
    if (_seeded) return;
    _seeded = true;
    _urlController.text = credentials.baseUrl;
    _apiKeyController.text = credentials.apiKey;
  }

  ArrApiClient _buildClient() => switch (widget.service) {
        ArrService.radarr => RadarrApiClient(
            baseUrl: _urlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
          ),
        ArrService.sonarr => SonarrApiClient(
            baseUrl: _urlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
          ),
      };

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final client = _buildClient();
    try {
      final result = await client.testConnection();
      if (!mounted) return;
      setState(() {
        _testResult = result;
        _testing = false;
      });
    } finally {
      client.close();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final credentials = ArrCredentials(
      baseUrl: _urlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
    );
    await ref
        .read(arrCredentialsProvider(widget.service).notifier)
        .save(credentials);
    if (!mounted) return;
    setState(() => _saving = false);
    KinosSnack.show('${widget.service.label} enregistré', context: context);
  }

  @override
  Widget build(BuildContext context) {
    // Ne préremplit les champs qu'une fois, à la première lecture réussie
    // du coffre sécurisé (`_seed` est idempotent) — sans quoi chaque
    // reconstruction écraserait ce que l'utilisateur est en train de
    // taper.
    ref.watch(arrCredentialsProvider(widget.service)).whenData(_seed);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.service.label,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          _ArrField(
            label: 'URL',
            hint: 'https://radarr.example.com',
            controller: _urlController,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ArrField(
            label: 'Clé API',
            hint: '',
            controller: _apiKeyController,
            obscure: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              FocusRing(
                borderRadius: AppRadii.controlBorder,
                onActivate: _testing ? null : _testConnection,
                child: ExcludeFocus(
                  child: OutlinedButton(
                    onPressed: _testing ? null : _testConnection,
                    child: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tester la connexion'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FocusRing(
                borderRadius: AppRadii.controlBorder,
                onActivate: _saving ? null : _save,
                child: ExcludeFocus(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Enregistrer'),
                  ),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _ArrTestResultLabel(result: _testResult!, service: widget.service),
          ],
        ],
      ),
    );
  }
}

class _QBittorrentSettingsCard extends ConsumerStatefulWidget {
  const _QBittorrentSettingsCard();

  @override
  ConsumerState<_QBittorrentSettingsCard> createState() =>
      _QBittorrentSettingsCardState();
}

class _QBittorrentSettingsCardState
    extends ConsumerState<_QBittorrentSettingsCard> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _seeded = false;
  bool _testing = false;
  bool? _testResult;
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _seed(QBittorrentCredentials credentials) {
    if (_seeded) return;
    _seeded = true;
    _urlController.text = credentials.baseUrl;
    _usernameController.text = credentials.username;
    _passwordController.text = credentials.password;
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final client = QBittorrentApiClient(
      baseUrl: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
    try {
      final result = await client.testConnection();
      if (!mounted) return;
      setState(() {
        _testResult = result;
        _testing = false;
      });
    } finally {
      client.close();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final credentials = QBittorrentCredentials(
      baseUrl: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
    await ref.read(qbittorrentCredentialsProvider.notifier).save(credentials);
    if (!mounted) return;
    setState(() => _saving = false);
    KinosSnack.show('qBittorrent enregistré', context: context);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(qbittorrentCredentialsProvider).whenData(_seed);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('qBittorrent',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          _ArrField(
            label: 'URL',
            hint: 'http://localhost:8080',
            controller: _urlController,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ArrField(
            label: "Nom d'utilisateur",
            hint: '',
            controller: _usernameController,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ArrField(
            label: 'Mot de passe',
            hint: '',
            controller: _passwordController,
            obscure: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              FocusRing(
                borderRadius: AppRadii.controlBorder,
                onActivate: _testing ? null : _testConnection,
                child: ExcludeFocus(
                  child: OutlinedButton(
                    onPressed: _testing ? null : _testConnection,
                    child: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tester la connexion'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FocusRing(
                borderRadius: AppRadii.controlBorder,
                onActivate: _saving ? null : _save,
                child: ExcludeFocus(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Enregistrer'),
                  ),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _testResult!
                  ? 'Connecté à qBittorrent'
                  : "Échec — vérifiez l'URL et les identifiants.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _testResult! ? AppColors.success : AppColors.error,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArrField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscure;

  const _ArrField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppColors.textPrimary),
      cursorColor: AppColors.textPrimary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint.isEmpty ? null : hint,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadii.controlBorder,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.controlBorder,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadii.controlBorder,
          borderSide: BorderSide(color: AppColors.focus),
        ),
      ),
    );
  }
}

class _ArrTestResultLabel extends StatelessWidget {
  final ArrConnectionResult result;
  final ArrService service;

  const _ArrTestResultLabel({required this.result, required this.service});

  String _errorMessage(ArrConnectionFailed failure) {
    final base = switch (failure.error) {
      ArrApiError.unreachable => 'Serveur injoignable.',
      ArrApiError.unauthorized => 'Clé API invalide.',
      ArrApiError.notFound => "Route introuvable — vérifiez l'URL.",
      ArrApiError.serverError => 'Le serveur a répondu une erreur.',
      ArrApiError.invalidResponse => 'Réponse inattendue.',
    };
    return failure.detail == null ? base : '$base ${failure.detail}';
  }

  @override
  Widget build(BuildContext context) {
    final (message, color) = switch (result) {
      ArrConnectionOk(:final version) => (
          'Connecté — ${service.label} v$version',
          AppColors.success
        ),
      ArrConnectionFailed failure => (_errorMessage(failure), AppColors.error),
    };
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
    );
  }
}
