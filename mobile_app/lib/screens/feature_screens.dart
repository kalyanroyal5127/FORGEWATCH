import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/machine_reading.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/forge_components.dart';

class FeatureScreen extends StatelessWidget {
  const FeatureScreen(
      {super.key,
      required this.page,
      required this.refreshVersion,
      required this.api,
      required this.user,
      required this.machines,
      required this.loading,
      required this.error,
      required this.onRefresh,
      required this.onSignOut});
  final String page;
  final int refreshVersion;
  final ApiClient api;
  final AuthUser user;
  final List<MachineReading> machines;
  final bool loading;
  final String? error;
  final Future<void> Function({bool silent}) onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => switch (page) {
        'Overview' => _overview(context),
        'Live Monitoring' => _live(),
        'AI Fault Detection' => _ai(),
        'Predictive Analysis' => _predictive(),
        '3D Digital Twin' => _TwinPage(machines: machines),
        'Simulation Control' => _SimulationPage(
            api: api,
            user: user,
            machines: machines,
            refresh: onRefresh,
            refreshVersion: refreshVersion),
        'Machine Comparison' => _ComparisonPage(api: api),
        'Maintenance' => _MaintenancePage(
            api: api,
            user: user,
            machines: machines,
            refreshVersion: refreshVersion),
        'Performance Analytics' => _PerformancePage(api: api),
        'Alerts' => _AlertsPage(api: api, refreshVersion: refreshVersion),
        'Notifications' =>
          _NotificationsPage(api: api, refreshVersion: refreshVersion),
        'Reports' => _ReportsPage(api: api),
        _ => _ProfilePage(user: user, api: api, onSignOut: onSignOut),
      };

  Widget _overview(BuildContext context) {
    final normal = machines.where((m) => m.condition == 'Normal').length;
    final faults = machines.length - normal;
    final health = machines.isEmpty
        ? 0
        : machines.fold<double>(0, (sum, m) => sum + m.health) /
            machines.length;
    final history = machines.isEmpty
        ? null
        : _historyChart(api, machines.first, allSensors: true);
    return _scroll([
      _pageHeader('PLANT OPERATIONS / OVERVIEW', 'Machine intelligence'),
      LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
              width: width,
              child: MetricCard(
                  label: 'Machines',
                  value: '${machines.length}',
                  icon: Icons.precision_manufacturing,
                  note: 'Connected to simulator')),
          SizedBox(
              width: width,
              child: MetricCard(
                  label: 'Normal',
                  value: '$normal',
                  icon: Icons.check_circle_outline,
                  color: ForgeColors.green,
                  note: 'Within simulated limits')),
          SizedBox(
              width: width,
              child: MetricCard(
                  label: 'Active faults',
                  value: '$faults',
                  icon: Icons.warning_amber,
                  color: ForgeColors.danger,
                  note: 'Current classifications')),
          SizedBox(
              width: width,
              child: MetricCard(
                  label: 'Average health',
                  value: '${health.round()}%',
                  icon: Icons.health_and_safety_outlined,
                  note: 'Simulated estimate')),
        ]);
      }),
      const SizedBox(height: 14),
      if (machines.isNotEmpty) history!,
      if (machines.isNotEmpty) ...[
        const SizedBox(height: 14),
        ConditionMixChart(machines: machines)
      ],
      const SizedBox(height: 14),
      ForgePanel(
          title: 'Machine status',
          subtitle: 'Live readings from Flask · refreshes every five seconds',
          child: machines.isEmpty
              ? _empty('Waiting for the backend to return machine readings.')
              : Column(children: [
                  for (final machine in machines)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: MachineTile(machine: machine, onTap: () {}))
                ])),
      const SizedBox(height: 8),
      const _SimulatedFootnote(),
    ]);
  }

  Widget _live() => _scroll([
        _pageHeader('PLANT OPERATIONS / LIVE MONITORING', 'Sensor telemetry'),
        if (machines.isEmpty)
          _empty('Start the Flask simulator to receive live readings.'),
        for (final machine in machines) ...[
          MachineTile(machine: machine),
          const SizedBox(height: 12),
          _historyChart(api, machine,
              key: ValueKey('live-${machine.machineId}')),
          const SizedBox(height: 12),
        ],
        const _SimulatedFootnote(),
      ]);

  Widget _ai() => _scroll([
        _pageHeader('PLANT OPERATIONS / AI ANALYSIS', 'AI fault detection'),
        const ForgePanel(
            title: 'Model output',
            subtitle:
                'Current classification from the Flask Random Forest and Isolation Forest',
            child: Text(
                'Classification and anomaly scores are returned by the backend. This is not a prediction of future failure.',
                style: TextStyle(color: ForgeColors.muted, height: 1.5))),
        const SizedBox(height: 14),
        if (machines.isEmpty) _empty('No model outputs are available yet.'),
        for (final m in machines) ...[
          ForgePanel(
              title: '${m.machineId} · ${m.machineName}',
              trailing: ConditionBadge(condition: m.condition),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: MetricCard(
                              label: 'Confidence',
                              value:
                                  '${(m.confidence * 100).toStringAsFixed(1)}%',
                              icon: Icons.speed)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: MetricCard(
                              label: 'Health',
                              value: '${m.health.toStringAsFixed(0)}%',
                              icon: Icons.favorite_border,
                              color: m.health > 70
                                  ? ForgeColors.green
                                  : ForgeColors.warning))
                    ]),
                    const SizedBox(height: 12),
                    _keyValue('Severity', m.severity),
                    _keyValue(
                        'Anomaly score', m.anomalyScore.toStringAsFixed(5)),
                    _keyValue('Anomaly status',
                        m.isAnomaly ? 'Anomalous' : 'Normal range'),
                    const Divider(color: ForgeColors.border, height: 22),
                    Text('Primary sensor: ${_sensorName(m.primarySensor)}',
                        style: const TextStyle(
                            color: ForgeColors.cyan,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(m.explanation,
                        style: const TextStyle(color: ForgeColors.muted)),
                    if (m.contributions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final entry in m.contributions.entries)
                        _contribution(entry.key, entry.value)
                    ],
                  ])),
          const SizedBox(height: 12),
        ],
        const _SimulatedFootnote(),
      ]);

  Widget _predictive() => _scroll([
        _pageHeader(
            'PLANT OPERATIONS / PREDICTIVE ANALYSIS', 'Trend estimates'),
        const ForgePanel(
            title: 'Estimate disclaimer',
            child: Text(
                'Forecasts and remaining-useful-life values use simulated history and simple trend estimates. They are demonstrations, not validated industrial predictions or maintenance intervals.',
                style: TextStyle(color: ForgeColors.warning, height: 1.5))),
        const SizedBox(height: 14),
        if (machines.isEmpty)
          _empty(
              'Historical readings are needed before estimates can be displayed.'),
        for (final m in machines) ...[
          ForecastCharts(api: api, machine: m),
          const SizedBox(height: 12)
        ],
        const _SimulatedFootnote(),
      ]);
}

Widget _scroll(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: children);

Widget _pageHeader(String breadcrumb, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(breadcrumb,
          style: const TextStyle(
              color: ForgeColors.cyan,
              fontSize: 9,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(title,
          style: const TextStyle(
              fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.3)),
    ]));

Widget _empty(String message) => ForgePanel(
    title: 'No data yet',
    child: SizedBox(
        width: double.infinity,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ForgeColors.muted)))));

Widget _historyChart(ApiClient api, MachineReading machine,
        {Key? key, bool allSensors = false}) =>
    FutureBuilder<dynamic>(
      key: key,
      future: api.getList('/api/history',
          query: {'machine_id': machine.machineId, 'limit': '48'}),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorPanel(message: '${snapshot.error}');
        if (!snapshot.hasData) {
          return loadingPanel('Loading ${machine.machineId} history…');
        }
        final rows = (snapshot.data as List).whereType<Map>().toList();
        List<double> values(String key) =>
            rows.map((r) => _num(r[key])).toList();
        if (allSensors) {
          return Column(children: [
            LineChartPanel(
                title: '${machine.machineId} · Vibration',
                unit: 'mm/s · simulated history',
                series: [values('vibration')],
                labels: const ['Vibration']),
            const SizedBox(height: 12),
            LineChartPanel(
                title: '${machine.machineId} · Temperature',
                unit: '°C · simulated history',
                series: [values('temperature')],
                colors: const [ForgeColors.blue],
                labels: const ['Temperature']),
            const SizedBox(height: 12),
            LineChartPanel(
                title: '${machine.machineId} · Electrical current',
                unit: 'A · simulated history',
                series: [values('current')],
                colors: const [ForgeColors.warning],
                labels: const ['Current']),
          ]);
        }
        return Column(children: [
          LineChartPanel(
              title: '${machine.machineId} vibration',
              unit: 'mm/s',
              series: [values('vibration')],
              labels: const ['Vibration']),
          const SizedBox(height: 10),
          LineChartPanel(
              title: '${machine.machineId} temperature',
              unit: '°C',
              series: [values('temperature')],
              colors: const [ForgeColors.blue],
              labels: const ['Temperature']),
          const SizedBox(height: 10),
          LineChartPanel(
              title: '${machine.machineId} current',
              unit: 'A',
              series: [values('current')],
              colors: const [ForgeColors.warning],
              labels: const ['Current']),
        ]);
      },
    );

class ForecastCharts extends StatelessWidget {
  const ForecastCharts({super.key, required this.api, required this.machine});
  final ApiClient api;
  final MachineReading machine;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: api.get('/api/analysis/forecast',
            query: {'machine_id': machine.machineId, 'limit': '60'}),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorPanel(message: '${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return loadingPanel(
                'Calculating simulated trend for ${machine.machineId}…');
          }
          final data = snapshot.data!;
          final forecast = Map<String, dynamic>.from(data['forecast'] ?? {});
          final history =
              (data['history'] as List? ?? []).whereType<Map>().toList();
          List<double> actual(String feature) =>
              history.map((r) => _num(r[feature])).toList();
          List<double> predicted(String feature, String key) =>
              List<double>.from(
                  (forecast[feature]?[key] as List? ?? []).map(_num));
          final series = <(String, String, String, Color)>[
            ('vibration', 'Vibration trend', 'mm/s', ForgeColors.cyan),
            ('temperature', 'Temperature trend', '°C', ForgeColors.blue),
            ('current', 'Current trend', 'A', ForgeColors.warning),
          ];
          return Column(children: [
            for (final item in series) ...[
              LineChartPanel(
                  title: '${machine.machineId} · ${item.$2}',
                  unit:
                      '${item.$3} · actual history plus estimated trend and interval',
                  colors: [
                    item.$4,
                    ForgeColors.green,
                    ForgeColors.danger
                  ],
                  labels: const [
                    'Observed',
                    'Estimate',
                    'Range'
                  ],
                  series: [
                    actual(item.$1),
                    predicted(item.$1, 'values'),
                    predicted(item.$1, 'upper')
                  ]),
              const SizedBox(height: 10),
            ],
            ForgePanel(
                title: 'Remaining useful life estimate · ${machine.machineId}',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${machine.rulDays.toStringAsFixed(1)} simulated days',
                          style: const TextStyle(
                              color: ForgeColors.cyan,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      const Text(
                          'Backend estimate based on simulated degradation; not a validated equipment lifetime.',
                          style: TextStyle(
                              color: ForgeColors.muted, fontSize: 11)),
                    ])),
          ]);
        },
      );
}

class _TwinPage extends StatefulWidget {
  const _TwinPage({required this.machines});
  final List<MachineReading> machines;
  @override
  State<_TwinPage> createState() => _TwinPageState();
}

class _TwinPageState extends State<_TwinPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();
  String? selected;
  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.machines.where((m) => m.machineId == selected);
    final selectedMachine = matches.isNotEmpty
        ? matches.first
        : (widget.machines.isEmpty ? null : widget.machines.first);
    return ListView(padding: const EdgeInsets.all(16), children: [
      _pageHeader('PLANT OPERATIONS / TWIN', '3D digital twin'),
      ForgePanel(
          title: 'Interactive machine model',
          subtitle:
              'Animated visual state reflects the selected backend classification.',
          trailing: _machineDropdown(widget.machines, selectedMachine,
              (v) => setState(() => selected = v)),
          child: Column(children: [
            SizedBox(
                height: 250,
                width: double.infinity,
                child: AnimatedBuilder(
                    animation: _rotation,
                    builder: (_, __) => CustomPaint(
                        painter: _MachinePainter(
                            phase: _rotation.value,
                            condition:
                                selectedMachine?.condition ?? 'Unknown')))),
            if (selectedMachine != null) MachineTile(machine: selectedMachine),
            if (selectedMachine == null)
              _empty('Waiting for live simulated readings.'),
          ])),
      const SizedBox(height: 12),
      const _SimulatedFootnote(),
    ]);
  }
}

class _SimulationPage extends StatefulWidget {
  const _SimulationPage(
      {required this.api,
      required this.user,
      required this.machines,
      required this.refresh,
      required this.refreshVersion});
  final ApiClient api;
  final AuthUser user;
  final List<MachineReading> machines;
  final Future<void> Function({bool silent}) refresh;
  final int refreshVersion;
  @override
  State<_SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<_SimulationPage> {
  String? machineId;
  bool busy = false;
  String? message;
  String condition = 'Overheating';
  Future<Map<String, dynamic>>? status;
  bool get canControl =>
      widget.user.role == 'Admin' || widget.user.role == 'Engineer';
  @override
  void initState() {
    super.initState();
    status = widget.api.get('/api/simulation/status');
  }

  @override
  void didUpdateWidget(covariant _SimulationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      status = widget.api.get('/api/simulation/status');
    }
  }

  Future<void> _control(String action) async {
    if (!canControl || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.api.post('/api/simulation/control', {
        'action': action,
        if (action == 'inject')
          'machine_id': machineId ?? _firstOrNull(widget.machines)?.machineId,
        if (action == 'inject') 'condition': condition
      });
      status = widget.api.get('/api/simulation/status');
      await widget.refresh();
      if (mounted) {
        setState(() => message = action == 'inject'
            ? '$condition injected for ${machineId ?? _firstOrNull(widget.machines)?.machineId}.'
            : 'Simulation command sent: $action.');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => message = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _pageHeader('PLANT OPERATIONS / CONTROLS', 'Simulation control'),
        if (!canControl)
          const ForgePanel(
              title: 'Read only access',
              child: Text(
                  'Simulation controls require the Engineer or Admin role. Your account can still monitor all assigned dashboard data.',
                  style: TextStyle(color: ForgeColors.warning))),
        FutureBuilder<Map<String, dynamic>>(
            future: status,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorPanel(
                    message: '${snapshot.error}',
                    onRetry: () => setState(() =>
                        status = widget.api.get('/api/simulation/status')));
              }
              if (!snapshot.hasData) {
                return loadingPanel('Checking backend simulation state…');
              }
              return ForgePanel(
                  title: 'Simulation status',
                  trailing: Icon(Icons.circle,
                      size: 10,
                      color: snapshot.data!['state'] == 'running'
                          ? ForgeColors.green
                          : ForgeColors.warning),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${snapshot.data!['state']}'.toUpperCase(),
                            style: const TextStyle(
                                color: ForgeColors.cyan,
                                fontWeight: FontWeight.w900,
                                fontSize: 20)),
                        const SizedBox(height: 5),
                        Text(
                            '${(snapshot.data!['machines'] as List? ?? []).length} virtual machines connected',
                            style: const TextStyle(color: ForgeColors.muted)),
                      ]));
            }),
        const SizedBox(height: 12),
        ForgePanel(
            title: 'Simulation controls',
            subtitle: canControl
                ? 'Commands call the existing Flask simulation API.'
                : 'Controls disabled for your role.',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _controlButton('Start', Icons.play_arrow, 'start'),
                    _controlButton('Pause', Icons.pause, 'pause'),
                    _controlButton('Stop', Icons.stop, 'stop'),
                    _controlButton('Reset', Icons.restart_alt, 'reset'),
                  ]),
                  const Divider(height: 26, color: ForgeColors.border),
                  DropdownButtonFormField<String>(
                      initialValue:
                          widget.machines.any((m) => m.machineId == machineId)
                              ? machineId
                              : _firstOrNull(widget.machines)?.machineId,
                      decoration:
                          const InputDecoration(labelText: 'Virtual machine'),
                      items: [
                        for (final m in widget.machines)
                          DropdownMenuItem(
                              value: m.machineId, child: Text(m.machineId))
                      ],
                      onChanged: canControl
                          ? (v) => setState(() => machineId = v)
                          : null),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                      initialValue: condition,
                      decoration: const InputDecoration(
                          labelText: 'Inject simulated condition'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Overheating', child: Text('Overheating')),
                        DropdownMenuItem(
                            value: 'Abnormal Vibration',
                            child: Text('Abnormal vibration')),
                        DropdownMenuItem(
                            value: 'Overcurrent', child: Text('Overcurrent'))
                      ],
                      onChanged: canControl
                          ? (v) => setState(() => condition = v ?? condition)
                          : null),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                      onPressed:
                          canControl && !busy && widget.machines.isNotEmpty
                              ? () => _control('inject')
                              : null,
                      icon: const Icon(Icons.bolt),
                      label: const Text('Inject fault into simulator')),
                  if (message != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(message!,
                            style: const TextStyle(color: ForgeColors.cyan))),
                ])),
        const SizedBox(height: 12),
        if (widget.machines.isNotEmpty)
          ...widget.machines.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MachineTile(machine: m))),
        const _SimulatedFootnote(),
      ]);

  Widget _controlButton(String label, IconData icon, String action) =>
      OutlinedButton.icon(
          onPressed: canControl && !busy ? () => _control(action) : null,
          icon: Icon(icon, size: 18),
          label: Text(label));
}

class _ComparisonPage extends StatelessWidget {
  const _ComparisonPage({required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
      future: api.getList('/api/comparison'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            _pageHeader('PLANT OPERATIONS / COMPARISON', 'Machine comparison'),
            ErrorPanel(message: '${snapshot.error}')
          ]);
        }
        if (!snapshot.hasData) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            _pageHeader('PLANT OPERATIONS / COMPARISON', 'Machine comparison'),
            loadingPanel()
          ]);
        }
        final machines = (snapshot.data as List)
            .whereType<Map>()
            .map((m) => MachineReading.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        final rankings = [...machines]
          ..sort((a, b) => b.health.compareTo(a.health));
        return ListView(padding: const EdgeInsets.all(16), children: [
          _pageHeader('PLANT OPERATIONS / COMPARISON', 'Machine comparison'),
          ForgePanel(
              title: 'Sensor comparison',
              subtitle:
                  'Latest backend values · machines ranked by simulated health',
              child: machines.isEmpty
                  ? _empty('No machine data available.')
                  : SizedBox(
                      height: 260,
                      child: BarChart(BarChartData(
                        maxY: 100,
                        gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) =>
                                const FlLine(color: ForgeColors.border)),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true, reservedSize: 32)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) {
                                      final i = v.toInt();
                                      return i >= 0 && i < machines.length
                                          ? Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 7),
                                              child: Text(machines[i].machineId,
                                                  style: const TextStyle(
                                                      color: ForgeColors.muted,
                                                      fontSize: 9)))
                                          : const SizedBox.shrink();
                                    }))),
                        barGroups: [
                          for (var i = 0; i < machines.length; i++)
                            BarChartGroupData(x: i, barsSpace: 4, barRods: [
                              BarChartRodData(
                                  toY: machines[i].health.clamp(0, 100),
                                  color: ForgeColors.cyan,
                                  width: 9,
                                  borderRadius: BorderRadius.circular(3)),
                              BarChartRodData(
                                  toY: (machines[i].temperature).clamp(0, 100),
                                  color: ForgeColors.blue,
                                  width: 9,
                                  borderRadius: BorderRadius.circular(3)),
                              BarChartRodData(
                                  toY: (machines[i].vibration * 10)
                                      .clamp(0, 100),
                                  color: ForgeColors.warning,
                                  width: 9,
                                  borderRadius: BorderRadius.circular(3))
                            ])
                        ],
                      )))),
          const SizedBox(height: 8),
          const Wrap(spacing: 14, children: [
            _ChartLegend(color: ForgeColors.cyan, label: 'Health %'),
            _ChartLegend(color: ForgeColors.blue, label: 'Temp °C'),
            _ChartLegend(color: ForgeColors.warning, label: 'Vibration ×10')
          ]),
          const SizedBox(height: 14),
          ForgePanel(
              title: 'Health ranking',
              child: Column(children: [
                for (var i = 0; i < rankings.length; i++)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                          radius: 15,
                          backgroundColor: ForgeColors.elevated,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: ForgeColors.cyan,
                                  fontWeight: FontWeight.bold))),
                      title: Text(rankings[i].machineId),
                      subtitle: Text(rankings[i].condition),
                      trailing: Text(
                          '${rankings[i].health.toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.w800)))
              ])),
          const _SimulatedFootnote(),
        ]);
      });
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: ForgeColors.muted, fontSize: 10))
      ]);
}

class _MaintenancePage extends StatefulWidget {
  const _MaintenancePage(
      {required this.api,
      required this.user,
      required this.machines,
      required this.refreshVersion});
  final ApiClient api;
  final AuthUser user;
  final List<MachineReading> machines;
  final int refreshVersion;
  @override
  State<_MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<_MaintenancePage> {
  late Future<Map<String, dynamic>> data = widget.api.get('/api/maintenance');
  String? machineId, message;
  String kind = 'Inspection';
  DateTime? due;
  final notes = TextEditingController();
  bool busy = false;
  @override
  void didUpdateWidget(covariant _MaintenancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      data = widget.api.get('/api/maintenance');
    }
  }

  bool get canSchedule =>
      widget.user.role == 'Admin' || widget.user.role == 'Engineer';
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> schedule() async {
    if (!canSchedule || due == null || widget.machines.isEmpty || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.api.post('/api/maintenance', {
        'machine_id': machineId ?? widget.machines.first.machineId,
        'due_at': due!.toUtc().toIso8601String(),
        'kind': kind,
        'notes': notes.text.trim()
      });
      setState(() {
        data = widget.api.get('/api/maintenance');
        message = 'Service reminder scheduled.';
        notes.clear();
      });
    } on ApiException catch (e) {
      setState(() => message = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> complete(dynamic id) async {
    try {
      await widget.api.post('/api/maintenance/$id/complete');
      setState(() => data = widget.api.get('/api/maintenance'));
    } on ApiException catch (e) {
      if (mounted) setState(() => message = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (context, snapshot) {
        final upcoming = (snapshot.data?['upcoming'] as List? ?? []);
        final history = (snapshot.data?['history'] as List? ?? []);
        return ListView(padding: const EdgeInsets.all(16), children: [
          _pageHeader('PLANT OPERATIONS / SERVICE', 'Maintenance management'),
          const ForgePanel(
              title: 'Simulated maintenance estimates',
              child: Text(
                  'Service reminders use simulated machine conditions. They are demonstration reminders, not engineering service intervals.',
                  style: TextStyle(color: ForgeColors.warning))),
          const SizedBox(height: 12),
          if (!canSchedule)
            const ForgePanel(
                title: 'View only',
                child: Text(
                    'Scheduling and completing maintenance require the Engineer or Admin role.',
                    style: TextStyle(color: ForgeColors.muted))),
          if (canSchedule)
            ForgePanel(
                title: 'Schedule service',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                          initialValue: machineId ??
                              _firstOrNull(widget.machines)?.machineId,
                          decoration:
                              const InputDecoration(labelText: 'Machine'),
                          items: [
                            for (final m in widget.machines)
                              DropdownMenuItem(
                                  value: m.machineId, child: Text(m.machineId))
                          ],
                          onChanged: (v) => setState(() => machineId = v)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    due ?? now.add(const Duration(days: 7)),
                                firstDate: now,
                                lastDate: now.add(const Duration(days: 365)));
                            if (picked != null) {
                              setState(() => due = DateTime(
                                  picked.year, picked.month, picked.day, 9));
                            }
                          },
                          icon: const Icon(Icons.calendar_month),
                          label: Text(due == null
                              ? 'Choose due date'
                              : due!.toLocal().toString().split('.').first)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          initialValue: kind,
                          decoration:
                              const InputDecoration(labelText: 'Service type'),
                          items: const [
                            DropdownMenuItem(
                                value: 'Inspection', child: Text('Inspection')),
                            DropdownMenuItem(
                                value: 'Vibration review',
                                child: Text('Vibration review')),
                            DropdownMenuItem(
                                value: 'Thermal inspection',
                                child: Text('Thermal inspection')),
                            DropdownMenuItem(
                                value: 'Electrical review',
                                child: Text('Electrical review'))
                          ],
                          onChanged: (v) => setState(() => kind = v ?? kind)),
                      const SizedBox(height: 10),
                      TextField(
                          controller: notes,
                          decoration: const InputDecoration(
                              labelText: 'Notes',
                              hintText: 'Optional service notes')),
                      const SizedBox(height: 10),
                      FilledButton(
                          onPressed:
                              busy || due == null || widget.machines.isEmpty
                                  ? null
                                  : schedule,
                          child: Text(busy ? 'Saving…' : 'Schedule service')),
                      if (message != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(message!,
                                style:
                                    const TextStyle(color: ForgeColors.cyan))),
                    ])),
          const SizedBox(height: 12),
          if (snapshot.hasError)
            ErrorPanel(
                message: '${snapshot.error}',
                onRetry: () =>
                    setState(() => data = widget.api.get('/api/maintenance')))
          else if (!snapshot.hasData)
            loadingPanel('Loading service records…')
          else ...[
            ForgePanel(
                title: 'Upcoming service',
                child: upcoming.isEmpty
                    ? _empty('No service is currently scheduled.')
                    : Column(children: [
                        for (final item in upcoming)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  '${item['machine_id']} · ${item['kind']}'),
                              subtitle:
                                  Text('${item['due_at']}\n${item['notes']}'),
                              isThreeLine: true,
                              trailing: canSchedule
                                  ? IconButton(
                                      tooltip: 'Mark complete',
                                      onPressed: () => complete(item['id']),
                                      icon: const Icon(
                                          Icons.check_circle_outline,
                                          color: ForgeColors.green))
                                  : null)
                      ])),
            const SizedBox(height: 12),
            ForgePanel(
                title: 'Service history',
                child: history.isEmpty
                    ? _empty('No completed service records yet.')
                    : Column(children: [
                        for (final item in history)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.build_outlined,
                                  color: ForgeColors.cyan),
                              title: Text(
                                  '${item['machine_id']} · ${item['kind']}'),
                              subtitle: Text(
                                  '${item['service_at']} · ${item['performed_by']}'))
                      ])),
          ],
          const _SimulatedFootnote(),
        ]);
      });
}

class _PerformancePage extends StatelessWidget {
  const _PerformancePage({required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: api.get('/api/analytics/oee'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            _pageHeader(
                'PLANT OPERATIONS / ANALYTICS', 'Performance analytics'),
            ErrorPanel(message: '${snapshot.error}')
          ]);
        }
        if (!snapshot.hasData) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            _pageHeader(
                'PLANT OPERATIONS / ANALYTICS', 'Performance analytics'),
            loadingPanel()
          ]);
        }
        final d = snapshot.data!;
        return ListView(padding: const EdgeInsets.all(16), children: [
          _pageHeader('PLANT OPERATIONS / ANALYTICS', 'Performance analytics'),
          const ForgePanel(
              title: 'OEE demonstration',
              child: Text(
                  'This simulated OEE index is calculated from database samples and alert conditions. It is not industrial KPI validation.',
                  style: TextStyle(color: ForgeColors.warning))),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 12) / 2;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: w,
                  child: MetricCard(
                      label: 'OEE index',
                      value: '${d['oee'] ?? 0}%',
                      icon: Icons.speed,
                      color: ForgeColors.cyan)),
              SizedBox(
                  width: w,
                  child: MetricCard(
                      label: 'Availability',
                      value: '${d['availability'] ?? 0}%',
                      icon: Icons.power_settings_new,
                      color: ForgeColors.green)),
              SizedBox(
                  width: w,
                  child: MetricCard(
                      label: 'Performance',
                      value: '${d['performance'] ?? 0}%',
                      icon: Icons.trending_up,
                      color: ForgeColors.blue)),
              SizedBox(
                  width: w,
                  child: MetricCard(
                      label: 'Quality',
                      value: '${d['quality'] ?? 0}%',
                      icon: Icons.verified_outlined,
                      color: ForgeColors.warning)),
            ]);
          }),
          const SizedBox(height: 14),
          ForgePanel(
              title: 'Data coverage',
              child: Column(children: [
                _keyValue('Reading samples', '${d['samples'] ?? 0}'),
                _keyValue('Fault samples', '${d['fault_samples'] ?? 0}'),
                _keyValue('Downtime events', '${d['downtime_events'] ?? 0}')
              ])),
          const SizedBox(height: 8),
          Text('${d['label'] ?? 'SIMULATED ANALYTICS'}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ForgeColors.muted, fontSize: 9)),
        ]);
      });
}

class _AlertsPage extends StatefulWidget {
  const _AlertsPage({required this.api, required this.refreshVersion});
  final ApiClient api;
  final int refreshVersion;
  @override
  State<_AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<_AlertsPage> {
  final search = TextEditingController();
  String severity = '';
  late Future<dynamic> future = _load();
  @override
  void didUpdateWidget(covariant _AlertsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) future = _load();
  }

  Future<dynamic> _load() => widget.api.getList('/api/alerts', query: {
        if (search.text.trim().isNotEmpty) 'q': search.text.trim(),
        if (severity.isNotEmpty) 'severity': severity
      });
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> act(dynamic id, String action) async {
    try {
      await widget.api.post('/api/alerts/$id/action', {'action': action});
      setState(() => future = _load());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
      future: future,
      builder: (context, s) =>
          ListView(padding: const EdgeInsets.all(16), children: [
            _pageHeader('PLANT OPERATIONS / ALERTS', 'Fault alerts'),
            ForgePanel(
                title: 'Filter alerts',
                child: Column(children: [
                  TextField(
                      controller: search,
                      decoration: InputDecoration(
                          labelText: 'Search machine or fault',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                              onPressed: () => setState(() => future = _load()),
                              icon: const Icon(Icons.arrow_forward))),
                      onSubmitted: (_) => setState(() => future = _load())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                      initialValue: severity,
                      decoration: const InputDecoration(labelText: 'Severity'),
                      items: const [
                        DropdownMenuItem(
                            value: '', child: Text('All severities')),
                        DropdownMenuItem(
                            value: 'Critical', child: Text('Critical')),
                        DropdownMenuItem(
                            value: 'Warning', child: Text('Warning')),
                        DropdownMenuItem(value: 'Low', child: Text('Low'))
                      ],
                      onChanged: (v) => setState(() {
                            severity = v ?? '';
                            future = _load();
                          }))
                ])),
            const SizedBox(height: 12),
            if (s.hasError)
              ErrorPanel(
                  message: '${s.error}',
                  onRetry: () => setState(() => future = _load()))
            else if (!s.hasData)
              loadingPanel('Loading alert history…')
            else if ((s.data as List).isEmpty)
              _empty('No matching fault alerts.')
            else
              ForgePanel(
                  title: 'Alert history',
                  child: Column(children: [
                    for (final a in (s.data as List))
                      Card(
                          color: ForgeColors.background,
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Icon(Icons.flag,
                                          color: a['severity'] == 'Critical'
                                              ? ForgeColors.danger
                                              : ForgeColors.warning),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              '${a['machine_id']} · ${a['condition']}',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w800))),
                                      ConditionBadge(
                                          condition: '${a['severity']}')
                                    ]),
                                    const SizedBox(height: 6),
                                    Text('${a['message'] ?? ''}',
                                        style: const TextStyle(
                                            color: ForgeColors.muted,
                                            fontSize: 12)),
                                    Text(
                                        '${a['timestamp'] ?? ''} · ${a['status'] ?? 'Open'}',
                                        style: const TextStyle(
                                            color: ForgeColors.muted,
                                            fontSize: 10)),
                                    if (a['status'] != 'Resolved')
                                      Wrap(children: [
                                        TextButton(
                                            onPressed: () =>
                                                act(a['id'], 'acknowledge'),
                                            child: const Text('Acknowledge')),
                                        TextButton(
                                            onPressed: () =>
                                                act(a['id'], 'resolve'),
                                            child: const Text('Resolve'))
                                      ])
                                  ])))
                  ])),
          ]));
}

class _NotificationsPage extends StatefulWidget {
  const _NotificationsPage({required this.api, required this.refreshVersion});
  final ApiClient api;
  final int refreshVersion;
  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  late Future<dynamic> future = widget.api.getList('/api/notifications');
  @override
  void didUpdateWidget(covariant _NotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      future = widget.api.getList('/api/notifications');
    }
  }

  Future<void> read(dynamic id) async {
    try {
      await widget.api.post('/api/notifications/$id/read');
      setState(() => future = widget.api.getList('/api/notifications'));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
      future: future,
      builder: (context, s) =>
          ListView(padding: const EdgeInsets.all(16), children: [
            _pageHeader('PLANT OPERATIONS / INBOX', 'Notification centre'),
            const ForgePanel(
                title: 'Notifications',
                subtitle:
                    'Fault updates and maintenance reminders are returned by your backend.',
                child: SizedBox.shrink()),
            const SizedBox(height: 12),
            if (s.hasError)
              ErrorPanel(
                  message: '${s.error}',
                  onRetry: () => setState(
                      () => future = widget.api.getList('/api/notifications')))
            else if (!s.hasData)
              loadingPanel()
            else if ((s.data as List).isEmpty)
              _empty('No notifications have been recorded.')
            else
              ForgePanel(
                  title: 'Recent notifications',
                  child: Column(children: [
                    for (final n in (s.data as List))
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                              n['kind'] == 'Fault'
                                  ? Icons.warning_amber
                                  : Icons.build_outlined,
                              color: n['severity'] == 'Critical'
                                  ? ForgeColors.danger
                                  : ForgeColors.cyan),
                          title: Text('${n['kind']} · ${n['severity']}'),
                          subtitle: Text('${n['message']}\n${n['timestamp']}',
                              style: const TextStyle(fontSize: 11)),
                          isThreeLine: true,
                          trailing: n['read'] == 1
                              ? const Icon(Icons.done, color: ForgeColors.green)
                              : IconButton(
                                  tooltip: 'Mark read',
                                  onPressed: () => read(n['id']),
                                  icon: const Icon(
                                      Icons.mark_email_read_outlined)))
                  ]))
          ]));
}

class _ReportsPage extends StatefulWidget {
  const _ReportsPage({required this.api});
  final ApiClient api;
  @override
  State<_ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<_ReportsPage> {
  String? busy, error;
  Future<void> export(String format) async {
    setState(() {
      busy = format;
      error = null;
    });
    try {
      switch (format) {
        case 'CSV':
          await widget.api.downloadAndShare(
              '/api/reports.csv', 'forgewatch_report.csv', 'text/csv');
          break;
        case 'Excel':
          await widget.api.downloadAndShare(
              '/api/reports.xlsx',
              'forgewatch_report.xlsx',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          break;
        default:
          await widget.api.downloadAndShare(
              '/api/reports.pdf', 'forgewatch_report.pdf', 'application/pdf');
          break;
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _pageHeader('PLANT OPERATIONS / REPORTING', 'Reports'),
        const ForgePanel(
            title: 'Export backend records',
            subtitle:
                'Reports are generated from machine readings and fault history stored by Flask.',
            child: SizedBox.shrink()),
        const SizedBox(height: 12),
        for (final item in [
          ('CSV', 'Comma-separated sensor history', Icons.table_chart_outlined),
          (
            'Excel',
            'Workbook with machine statistics and fault history',
            Icons.grid_on_outlined
          ),
          ('PDF', 'Printable machine report', Icons.picture_as_pdf_outlined)
        ])
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ForgePanel(
                  title: '${item.$1} report',
                  subtitle: item.$2,
                  child: FilledButton.tonalIcon(
                      onPressed: busy == null ? () => export(item.$1) : null,
                      icon: busy == item.$1
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(item.$3),
                      label: Text(busy == item.$1
                          ? 'Preparing report…'
                          : 'Download and share ${item.$1}')))),
        if (error != null) ErrorPanel(message: error!),
        const SizedBox(height: 10),
        const Text(
            'Report contents contain simulated sensor readings. Treat estimates as educational data.',
            style: TextStyle(color: ForgeColors.muted, fontSize: 11))
      ]);
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage(
      {required this.user, required this.api, required this.onSignOut});
  final AuthUser user;
  final ApiClient api;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _pageHeader('PLANT OPERATIONS / ACCOUNT', 'Profile'),
        ForgePanel(
            title: 'Signed-in account',
            child: Column(children: [
              CircleAvatar(
                  radius: 36,
                  backgroundColor: ForgeColors.blue,
                  child: Text(user.username[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              Text(user.username,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              ConditionBadge(condition: user.role),
              const SizedBox(height: 16),
              _keyValue('Authentication', 'Flask API bearer token'),
              _keyValue('Session storage', 'Encrypted Android secure storage'),
              _keyValue('API connection', api.baseUrl)
            ])),
        const SizedBox(height: 12),
        const ForgePanel(
            title: 'Role permissions',
            child: Text(
                'Your dashboard controls and actions follow the Admin, Engineer, or Operator role returned by Flask. Restricted actions remain enforced by the API.',
                style: TextStyle(color: ForgeColors.muted, height: 1.5))),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'))
      ]);
}

class _MachinePainter extends CustomPainter {
  _MachinePainter({required this.phase, required this.condition});
  final double phase;
  final String condition;
  @override
  void paint(Canvas canvas, Size size) {
    final stateColor = condition == 'Normal'
        ? ForgeColors.green
        : condition == 'Unknown'
            ? ForgeColors.muted
            : ForgeColors.danger;
    final center = Offset(size.width / 2, size.height / 2 + 14);
    final glow = Paint()..color = stateColor.withValues(alpha: .11);
    canvas.drawCircle(center, 94 + 6 * math.sin(phase * math.pi * 2), glow);
    final edge = Paint()
      ..color = ForgeColors.cyan.withValues(alpha: .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fill = Paint()..color = ForgeColors.elevated;
    final machine = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 150, height: 96),
        const Radius.circular(16));
    canvas.drawRRect(machine, fill);
    canvas.drawRRect(machine, edge);
    final motor = Paint()..color = ForgeColors.card;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: center.translate(-6, 0), width: 78, height: 60),
            const Radius.circular(12)),
        motor);
    canvas.drawCircle(center.translate(10, 0), 24, edge);
    final rotor = Paint()
      ..color = stateColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(center.dx + 10, center.dy);
    canvas.rotate(phase * math.pi * 2);
    for (var i = 0; i < 4; i++) {
      canvas.rotate(math.pi / 2);
      canvas.drawLine(const Offset(0, -3), const Offset(0, -18), rotor);
    }
    canvas.restore();
    final base = Paint()..color = ForgeColors.border;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: center.translate(0, 58), width: 178, height: 13),
            const Radius.circular(5)),
        base);
    final text = TextPainter(
        text: TextSpan(
            text: condition.toUpperCase(),
            style: TextStyle(
                color: stateColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4)),
        textDirection: TextDirection.ltr)
      ..layout();
    text.paint(canvas, Offset(center.dx - text.width / 2, center.dy + 77));
  }

  @override
  bool shouldRepaint(covariant _MachinePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.condition != condition;
}

Widget _machineDropdown(List<MachineReading> machines, MachineReading? selected,
    ValueChanged<String?> onChanged) {
  if (machines.isEmpty) return const SizedBox.shrink();
  return DropdownButton<String>(
      value: selected?.machineId,
      underline: const SizedBox.shrink(),
      dropdownColor: ForgeColors.card,
      items: [
        for (final m in machines)
          DropdownMenuItem(value: m.machineId, child: Text(m.machineId))
      ],
      onChanged: onChanged);
}

double _num(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _sensorName(String value) => switch (value) {
      'vibration' => 'Vibration',
      'temperature' => 'Temperature',
      'current' => 'Electrical current',
      _ => value
    };
Widget _keyValue(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(
          child: Text(label,
              style: const TextStyle(color: ForgeColors.muted, fontSize: 12))),
      Text(value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))
    ]));
Widget _contribution(String name, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(
          width: 90,
          child: Text(_sensorName(name),
              style: const TextStyle(fontSize: 10, color: ForgeColors.muted))),
      Expanded(
          child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: value.clamp(0, 1),
                  minHeight: 5,
                  color: ForgeColors.cyan,
                  backgroundColor: ForgeColors.elevated))),
      const SizedBox(width: 8),
      Text(value.toStringAsFixed(3), style: const TextStyle(fontSize: 10))
    ]));

class _SimulatedFootnote extends StatelessWidget {
  const _SimulatedFootnote();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.all(8),
      child: Text(
          'FORGEWATCH · Educational software demonstration · All readings are simulated · Current condition classification, not future failure prediction',
          textAlign: TextAlign.center,
          style:
              TextStyle(color: ForgeColors.muted, fontSize: 9, height: 1.5)));
}

T? _firstOrNull<T>(Iterable<T> values) => values.isEmpty ? null : values.first;
