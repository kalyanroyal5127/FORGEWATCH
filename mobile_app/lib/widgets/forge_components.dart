import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/machine_reading.dart';
import '../theme.dart';

class ForgePanel extends StatelessWidget {
  const ForgePanel(
      {super.key,
      required this.title,
      required this.child,
      this.trailing,
      this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800))),
              if (trailing != null) trailing!
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style:
                      const TextStyle(color: ForgeColors.muted, fontSize: 12))
            ],
            const SizedBox(height: 14),
            child,
          ])));
}

class MetricCard extends StatelessWidget {
  const MetricCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.color = ForgeColors.cyan,
      this.note});
  final String label, value;
  final IconData icon;
  final Color color;
  final String? note;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(height: 12),
            Text(label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: ForgeColors.muted,
                    fontSize: 10,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(
                    color: color == ForgeColors.cyan ? ForgeColors.text : color,
                    fontWeight: FontWeight.w900,
                    fontSize: 24)),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(note!,
                  style:
                      const TextStyle(color: ForgeColors.muted, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)
            ],
          ])));
}

class ConditionBadge extends StatelessWidget {
  const ConditionBadge({super.key, required this.condition});
  final String condition;
  @override
  Widget build(BuildContext context) {
    final color = condition == 'Normal'
        ? ForgeColors.green
        : condition == 'Unknown'
            ? ForgeColors.muted
            : ForgeColors.danger;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .4))),
        child: Text(condition.toUpperCase(),
            style: TextStyle(
                color: color,
                fontSize: 9,
                letterSpacing: .5,
                fontWeight: FontWeight.w800)));
  }
}

class MachineTile extends StatelessWidget {
  const MachineTile({super.key, required this.machine, this.onTap});
  final MachineReading machine;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.precision_manufacturing_outlined,
                          color: ForgeColors.cyan),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(machine.machineId,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            Text(machine.machineName,
                                style: const TextStyle(
                                    fontSize: 11, color: ForgeColors.muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)
                          ])),
                      ConditionBadge(condition: machine.condition)
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                          child: _reading('VIBRATION',
                              '${machine.vibration.toStringAsFixed(2)} mm/s')),
                      Expanded(
                          child: _reading('TEMP',
                              '${machine.temperature.toStringAsFixed(1)} °C')),
                      Expanded(
                          child: _reading('CURRENT',
                              '${machine.current.toStringAsFixed(2)} A'))
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Text('HEALTH',
                          style: TextStyle(
                              color: ForgeColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('${machine.health.toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold))
                    ]),
                    const SizedBox(height: 5),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                            value: (machine.health / 100).clamp(0, 1),
                            minHeight: 6,
                            backgroundColor: ForgeColors.elevated,
                            color: machine.health > 70
                                ? ForgeColors.green
                                : ForgeColors.warning)),
                  ]))));
  Widget _reading(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: ForgeColors.muted, fontSize: 9)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))
      ]);
}

class LineChartPanel extends StatelessWidget {
  const LineChartPanel(
      {super.key,
      required this.title,
      required this.series,
      this.colors,
      this.labels,
      this.height = 210,
      this.unit});
  final String title;
  final List<List<double>> series;
  final List<Color>? colors;
  final List<String>? labels;
  final double height;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final usable = series.where((points) => points.length > 1).toList();
    if (usable.isEmpty) {
      return ForgePanel(
          title: title,
          child: SizedBox(
              height: height,
              child: const Center(
                  child: Text('Collecting backend readings…',
                      style: TextStyle(color: ForgeColors.muted)))));
    }
    final maxY = usable
        .expand((points) => points)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final minY = usable
        .expand((points) => points)
        .fold<double>(double.infinity, (a, b) => a < b ? a : b);
    final span = (maxY - minY).abs();
    final padding = span == 0 ? (maxY.abs() * .15 + 1) : span * .18;
    final palette = colors ??
        const [ForgeColors.cyan, ForgeColors.blue, ForgeColors.warning];
    return ForgePanel(
        title: title,
        subtitle: unit,
        child: Column(children: [
          if (labels != null)
            Wrap(spacing: 14, children: [
              for (var i = 0; i < labels!.length; i++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: palette[i % palette.length],
                          shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(labels![i],
                      style: const TextStyle(
                          color: ForgeColors.muted, fontSize: 10))
                ])
            ]),
          if (labels != null) const SizedBox(height: 10),
          SizedBox(
              height: height,
              child: LineChart(LineChartData(
                minY: (minY - padding).clamp(0, double.infinity),
                maxY: maxY + padding,
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                        color: ForgeColors.border, strokeWidth: .7)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: (maxY - minY + 2 * padding) / 4,
                            getTitlesWidget: (v, _) => Text(
                                v.toStringAsFixed(0),
                                style: const TextStyle(
                                    color: ForgeColors.muted, fontSize: 9)))),
                    bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false))),
                lineBarsData: [
                  for (var i = 0; i < usable.length; i++)
                    LineChartBarData(
                        spots: [
                          for (var j = 0; j < usable[i].length; j++)
                            FlSpot(j.toDouble(), usable[i][j])
                        ],
                        isCurved: true,
                        barWidth: 2.4,
                        color: palette[i % palette.length],
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                            show: i == 0,
                            color: palette[i % palette.length]
                                .withValues(alpha: .09)))
                ],
              ))),
        ]));
  }
}

class ConditionMixChart extends StatelessWidget {
  const ConditionMixChart({super.key, required this.machines});
  final List<MachineReading> machines;
  @override
  Widget build(BuildContext context) {
    final normal = machines.where((m) => m.condition == 'Normal').length;
    final fault = machines.length - normal;
    return ForgePanel(
        title: 'Condition mix',
        subtitle: 'Live backend classifications',
        child: SizedBox(
            height: 205,
            child: machines.isEmpty
                ? const Center(
                    child: Text('No machine data yet',
                        style: TextStyle(color: ForgeColors.muted)))
                : Row(children: [
                    Expanded(
                        child: PieChart(PieChartData(
                            centerSpaceRadius: 48,
                            sectionsSpace: 3,
                            sections: [
                          PieChartSectionData(
                              value:
                                  normal.toDouble().clamp(0, double.infinity),
                              color: ForgeColors.green,
                              title: '$normal',
                              radius: 28,
                              titleStyle: const TextStyle(
                                  color: ForgeColors.background,
                                  fontWeight: FontWeight.w900)),
                          if (fault > 0)
                            PieChartSectionData(
                                value: fault.toDouble(),
                                color: ForgeColors.danger,
                                title: '$fault',
                                radius: 28,
                                titleStyle: const TextStyle(
                                    color: ForgeColors.background,
                                    fontWeight: FontWeight.w900)),
                        ]))),
                    const SizedBox(width: 12),
                    Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _legend(ForgeColors.green, 'Normal  $normal'),
                          const SizedBox(height: 12),
                          _legend(ForgeColors.danger, 'Fault  $fault')
                        ])
                  ])));
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: ForgeColors.muted))
      ]);
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => ForgePanel(
      title: 'Connection issue',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: const TextStyle(color: ForgeColors.warning)),
        if (onRetry != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'))
        ],
      ]));
}

Widget loadingPanel([String message = 'Loading live backend data…']) =>
    ForgePanel(
        title: 'Loading',
        child: SizedBox(
            height: 100,
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(height: 10),
              Text(message,
                  style:
                      const TextStyle(color: ForgeColors.muted, fontSize: 12))
            ]))));
