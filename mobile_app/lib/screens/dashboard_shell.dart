import 'dart:async';
import 'package:flutter/material.dart';
import '../models/machine_reading.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'feature_screens.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell(
      {super.key,
      required this.api,
      required this.user,
      required this.onSignedOut});
  final ApiClient api;
  final AuthUser user;
  final VoidCallback onSignedOut;
  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  static const _pages = <String>[
    'Overview',
    'Live Monitoring',
    'AI Fault Detection',
    'Predictive Analysis',
    '3D Digital Twin',
    'Simulation Control',
    'Machine Comparison',
    'Maintenance',
    'Performance Analytics',
    'Alerts',
    'Notifications',
    'Reports',
    'Profile',
  ];
  static const _icons = <IconData>[
    Icons.dashboard_outlined,
    Icons.monitor_heart_outlined,
    Icons.auto_awesome,
    Icons.query_stats,
    Icons.view_in_ar,
    Icons.tune,
    Icons.compare_arrows,
    Icons.build_circle_outlined,
    Icons.analytics_outlined,
    Icons.flag_outlined,
    Icons.notifications_none,
    Icons.summarize_outlined,
    Icons.account_circle_outlined,
  ];
  String _page = 'Overview';
  List<MachineReading> _machines = [];
  String? _error;
  bool _loading = true, _paused = false;
  int _refreshVersion = 0;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _load();
    _poller =
        Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await widget.api.get('/api/snapshot');
      final values = (data['machines'] as List? ?? [])
          .whereType<Map>()
          .map((item) =>
              MachineReading.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (mounted) {
        setState(() {
          _machines = values;
          _paused = data['paused'] == true;
          _error = null;
          _loading = false;
          _refreshVersion++;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await widget.api.signOut();
        if (mounted) widget.onSignedOut();
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not read the machine data returned by the server.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await widget.api.signOut();
    if (mounted) widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPages = [
      'Overview',
      'Live Monitoring',
      'AI Fault Detection',
      'Alerts',
      'Profile'
    ];
    final bottomIndex = bottomPages.indexOf(_page);
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
            builder: (context) => IconButton(
                tooltip: 'Open navigation',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer())),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('FORGEWATCH',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 15,
                  color: ForgeColors.cyan)),
          Text(_page.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9, letterSpacing: .9, color: ForgeColors.muted)),
        ]),
        actions: [
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(
                tooltip: 'Refresh',
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh)),
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                  radius: 17,
                  backgroundColor: ForgeColors.blue,
                  child: Text(
                      widget.user.username.isEmpty
                          ? 'U'
                          : widget.user.username[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)))),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: _pages.indexOf(_page),
        onDestinationSelected: (index) {
          Navigator.pop(context);
          setState(() => _page = _pages[index]);
        },
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.diamond_outlined,
                        color: ForgeColors.cyan, size: 32),
                    const SizedBox(height: 8),
                    const Text('FORGEWATCH',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const Text('MACHINE INTELLIGENCE',
                        style: TextStyle(
                            color: ForgeColors.muted,
                            fontSize: 9,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text(
                        '${widget.user.username}  ·  ${widget.user.role.toUpperCase()}',
                        style: const TextStyle(
                            color: ForgeColors.cyan, fontSize: 11)),
                  ])),
          const Divider(color: ForgeColors.border, indent: 16, endIndent: 16),
          for (var i = 0; i < _pages.length; i++)
            NavigationDrawerDestination(
                icon: Icon(_icons[i], color: ForgeColors.cyan),
                label: Text(_pages[i])),
          const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text('SIMULATED DATA · CURRENT CONDITION CLASSIFICATION',
                  style: TextStyle(
                      color: ForgeColors.muted,
                      fontSize: 9,
                      letterSpacing: .5))),
        ],
      ),
      body: Column(children: [
        if (_error != null)
          Material(
              color: ForgeColors.danger.withValues(alpha: .12),
              child: ListTile(
                  dense: true,
                  leading:
                      const Icon(Icons.cloud_off, color: ForgeColors.warning),
                  title: Text(_error!, style: const TextStyle(fontSize: 12)),
                  trailing: TextButton(
                      onPressed: () => _load(), child: const Text('Retry')))),
        if (_paused)
          const Material(
              color: ForgeColors.warning,
              child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                      padding: EdgeInsets.all(7),
                      child: Text(
                          'SIMULATION PAUSED · showing last backend readings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: ForgeColors.background,
                              fontSize: 10,
                              fontWeight: FontWeight.bold))))),
        Expanded(
            child: RefreshIndicator(
                onRefresh: () => _load(),
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: FeatureScreen(
                        key: ValueKey(_page),
                        page: _page,
                        refreshVersion: _refreshVersion,
                        api: widget.api,
                        user: widget.user,
                        machines: _machines,
                        loading: _loading,
                        error: _error,
                        onRefresh: _load,
                        onSignOut: _logout)))),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex < 0 ? 0 : bottomIndex,
        onDestinationSelected: (index) =>
            setState(() => _page = bottomPages[index]),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Overview'),
          NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon: Icon(Icons.monitor_heart),
              label: 'Live'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'AI'),
          NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Alerts'),
          NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle),
              label: 'Profile'),
        ],
      ),
    );
  }
}
