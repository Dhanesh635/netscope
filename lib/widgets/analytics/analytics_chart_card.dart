import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../glass_card.dart';

class AnalyticsChartCard extends StatelessWidget {
  const AnalyticsChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.lineColor,
    required this.spots,
    required this.minY,
    required this.maxY,
  });

  final String title;
  final String subtitle;
  final Color lineColor;
  final List<FlSpot> spots;
  final double minY;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassCard(
      sigmaX: 16.0,
      sigmaY: 16.0,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              _buildData(theme),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildData(ThemeData theme) {
    final axisColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45);

    return LineChartData(
      minY: minY,
      maxY: maxY,
      minX: 0,
      maxX: (spots.length - 1).toDouble(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.16),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            getTitlesWidget: (value, meta) {
              final shouldShow = value == minY || value == maxY || value == 0;
              if (!shouldShow) {
                return const SizedBox.shrink();
              }

              return SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toStringAsFixed(0),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: axisColor,
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (value % 2 != 0 && value != spots.length - 1) {
                return const SizedBox.shrink();
              }

              return SideTitleWidget(
                meta: meta,
                child: Text(
                  'T${value.toInt()}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: axisColor,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          color: lineColor,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: lineColor.withValues(alpha: 0.14),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                spot.y.toStringAsFixed(1),
                theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}