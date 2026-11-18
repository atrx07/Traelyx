import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/features/cloud_commentary/application/cloud_commentary_service.dart';
import 'package:traelyx/features/cloud_commentary/domain/cloud_commentary.dart';
import 'package:traelyx/features/local_commentary/presentation/local_commentary_card.dart';

class CloudCommentaryScreen extends ConsumerStatefulWidget {
  const CloudCommentaryScreen({super.key});
  @override
  ConsumerState<CloudCommentaryScreen> createState() =>
      _CloudCommentaryScreenState();
}

class _CloudCommentaryScreenState extends ConsumerState<CloudCommentaryScreen>
    with WidgetsBindingObserver {
  final _key = TextEditingController();
  final _custom = TextEditingController();
  CloudSetup? _setup;
  CloudModelMode _mode = CloudModelMode.automatic;
  String? _selectedModel;
  bool _parked = false;
  bool _busy = false;
  int _action = 0;
  String? _notice;
  late final CloudCommentaryService _service;
  @override
  void initState() {
    super.initState();
    _service = ref.read(cloudCommentaryServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    _run(_reload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.cancel();
    _key.dispose();
    _custom.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _service.cancel();
      _key.clear();
      if (mounted) setState(() => _parked = false);
    }
  }

  Future<void> _reload() async {
    final action = _action;
    final setup = await _service.load();
    if (!mounted || action != _action) return;
    setState(() {
      _setup = setup;
      _mode = setup.configuration.mode;
      _selectedModel = setup.configuration.model;
      _custom.text = _mode == CloudModelMode.custom
          ? setup.configuration.model!
          : '';
    });
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool interrupt = false,
  }) async {
    if (_busy && !interrupt) return;
    final id = ++_action;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted && id == _action) {
        setState(() => _notice = cloudFailureMessage(error));
      }
    } finally {
      if (mounted && id == _action) setState(() => _busy = false);
    }
  }

  Future<void> _permission(bool enabled) => _run(() async {
    final config = _setup!.configuration;
    await _service.configure(
      enabled: enabled,
      mode: config.mode,
      model: config.model,
    );
    await _reload();
    if (mounted) {
      setState(
        () => _notice = enabled
            ? 'Cloud requests are permitted, but every trip still needs a send review.'
            : 'Cloud permission is off. Already sent data cannot be recalled.',
      );
    }
  }, interrupt: !enabled);
  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    return Scaffold(
      appBar: AppBar(title: const Text('Commentary engine')),
      bottomNavigationBar: _notice == null
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  key: const ValueKey('cloud-settings-feedback'),
                  constraints: BoxConstraints(
                    maxHeight:
                        (MediaQuery.sizeOf(context).height -
                            MediaQuery.viewInsetsOf(context).bottom) *
                        .35,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _notice!,
                        key: const ValueKey('cloud-settings-notice'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Built-in narrator',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Always available offline, without a key, account or paid service. Silent sends nothing.',
                ),
                const SizedBox(height: 20),
                Text(
                  'Optional Groq cloud',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Cloud chooses among reviewed tone lines for existing replay moments. It cannot write unrestricted commentary or change detections, scores or safety alerts.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Groq receives your API key for authentication and network metadata such as your IP. Model refresh sends no trip data. Each trip request separately reviews categorical events, repetition context, tone and approved wording choices. No route, raw sensors, measurements, identifiers or times are sent.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your Groq account controls availability, charges and retention. Requests may cost money. Traelyx cannot guarantee zero retention or recall data already transmitted. See console.groq.com/docs/your-data.',
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Cloud action in progress…'),
                  ),
                if (setup == null)
                  TextButton(
                    onPressed: _busy ? null : () => _run(_reload),
                    child: const Text('Retry local settings'),
                  ),
                if (setup != null) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    key: const ValueKey('cloud-permission'),
                    title: const Text('Allow optional Groq requests'),
                    subtitle: const Text(
                      'Off by default. Saving or replacing a key turns this off. No automatic sends or retries.',
                    ),
                    value: setup.configuration.enabled,
                    onChanged: _busy && !setup.configuration.enabled
                        ? null
                        : _permission,
                  ),
                  Text(
                    setup.keySaved
                        ? 'Key saved securely on this device.'
                        : 'No key saved.',
                    key: const ValueKey('cloud-key-state'),
                  ),
                  TextField(
                    key: const ValueKey('cloud-key-input'),
                    controller: _key,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    autofillHints: const [],
                    maxLength: 256,
                    decoration: const InputDecoration(
                      labelText: 'New Groq API key',
                      helperText:
                          'Stored securely; never redisplayed or synced.',
                    ),
                    enabled: !_busy,
                  ),
                  FilledButton(
                    key: const ValueKey('cloud-save-key'),
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final value = _key.text;
                            _key.clear();
                            await _service.saveKey(value);
                            await _reload();
                            if (mounted) {
                              setState(
                                () => _notice =
                                    'Key saved. Cloud permission is off until you enable it.',
                              );
                            }
                          }),
                    child: const Text('Save key locally'),
                  ),
                  TextButton(
                    key: const ValueKey('cloud-remove-key'),
                    onPressed: () => _run(() async {
                      _key.clear();
                      await _service.removeKey();
                      await _reload();
                      if (mounted) {
                        setState(
                          () => _notice =
                              'Key removed and cloud permission turned off.',
                        );
                      }
                    }, interrupt: true),
                    child: const Text('Remove key and turn off cloud'),
                  ),
                  const Divider(height: 32),
                  CheckboxListTile(
                    key: const ValueKey('cloud-settings-parked'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I am parked and have finished driving'),
                    value: _parked,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _parked = v ?? false),
                  ),
                  OutlinedButton(
                    key: const ValueKey('cloud-refresh-models'),
                    onPressed:
                        _busy ||
                            !_parked ||
                            !setup.keySaved ||
                            !setup.configuration.enabled
                        ? null
                        : () => _run(() async {
                            final models = await _service.refreshModels(
                              parked: _parked,
                            );
                            await _reload();
                            if (mounted) {
                              setState(
                                () => _notice =
                                    'Connection accepted. ${models.length} candidate text ${models.length == 1 ? 'model' : 'models'} found. Chat compatibility and quality are not yet verified. No trip data sent.',
                              );
                            }
                          }),
                    child: const Text('Test connection / refresh models'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CloudModelMode>(
                    key: ValueKey(
                      'cloud-model-mode-${_setup!.configuration.revision}',
                    ),
                    initialValue: _mode,
                    decoration: const InputDecoration(
                      labelText: 'Model selection',
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: CloudModelMode.automatic,
                        child: Text('Automatic from discovered models'),
                      ),
                      DropdownMenuItem(
                        value: CloudModelMode.discovered,
                        child: Text('Choose a discovered model'),
                      ),
                      DropdownMenuItem(
                        value: CloudModelMode.custom,
                        child: Text('Advanced: custom model ID'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(
                            () => _mode = v ?? CloudModelMode.automatic,
                          ),
                  ),
                  if (_mode == CloudModelMode.automatic)
                    const Text(
                      'Refresh the catalog explicitly after startup or changing a key. Automatic picks a compatible-family candidate from that catalog; it is not a quality or price guarantee.',
                    ),
                  if (_mode == CloudModelMode.discovered)
                    DropdownButton<String>(
                      key: const ValueKey('cloud-discovered-model'),
                      isExpanded: true,
                      hint: const Text('Refresh models, then choose'),
                      value: setup.models.any((m) => m.id == _selectedModel)
                          ? _selectedModel
                          : null,
                      items: [
                        for (final model in setup.models)
                          DropdownMenuItem(
                            value: model.id,
                            child: Text(
                              model.id,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _selectedModel = v),
                    ),
                  if (_mode == CloudModelMode.custom)
                    TextField(
                      key: const ValueKey('cloud-custom-model'),
                      controller: _custom,
                      maxLength: 120,
                      autocorrect: false,
                      enableSuggestions: false,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Custom text model ID',
                        helperText:
                            'Compatibility, access and cost are not verified.',
                      ),
                    ),
                  TextButton(
                    key: const ValueKey('cloud-save-model'),
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await _service.configure(
                              enabled: setup.configuration.enabled,
                              mode: _mode,
                              model: _mode == CloudModelMode.automatic
                                  ? null
                                  : _mode == CloudModelMode.custom
                                  ? _custom.text
                                  : _selectedModel,
                            );
                            await _reload();
                            if (mounted) {
                              setState(
                                () => _notice =
                                    'Model selection saved. No network request made.',
                              );
                            }
                          }),
                    child: const Text('Save model selection'),
                  ),
                  TextButton(
                    onPressed: _busy ? () => _service.cancel() : null,
                    child: const Text('Cancel pending request'),
                  ),
                ],
                const SizedBox(height: 20),
                const LocalCommentaryCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
