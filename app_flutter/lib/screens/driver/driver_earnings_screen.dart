import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../constants/admin_theme.dart';
import '../../widgets/app_drawer.dart';

class DriverEarningsScreen extends StatelessWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Earnings & Stats'),
        backgroundColor: AdminTheme.secondaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AdminTheme.bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 24),
            const Text('Weekly Performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildChartCard(),
            const SizedBox(height: 24),
            const Text('Recent Payouts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPayoutList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: AdminTheme.secondaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Earnings',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 8),
                  const Text('R\$ 1,240.50',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(LucideIcons.dollarSign,
                  color: Colors.greenAccent, size: 32),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Card(
      color: AdminTheme.secondaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 20,
              barGroups: [
                _makeGroupData(0, 5),
                _makeGroupData(1, 6), // Tue
                _makeGroupData(2, 8),
                _makeGroupData(3, 7),
                _makeGroupData(4, 12), // Fri
                _makeGroupData(5, 15), // Sat
                _makeGroupData(6, 4), // Sun
              ],
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const titles = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      return Text(titles[value.toInt()],
                          style: const TextStyle(
                              color: Colors.white54, fontWeight: FontWeight.bold));
                    },
                  ),
                ),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AdminTheme.primaryColor,
          width: 16,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildPayoutList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          color: AdminTheme.secondaryColor,
          shape: RoundedRectangleBorder(side: BorderSide(color: Colors.white.withOpacity(0.05)), borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(LucideIcons.checkCircle, color: Colors.greenAccent),
            title: Text('Payout #${1000 + index}', style: const TextStyle(color: Colors.white)),
            subtitle: Text('Jan ${20 - index}, 2026', style: const TextStyle(color: Colors.white54)),
            trailing: Text('R\$ ${350 - (index * 50)}.00',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          ),
        );
      },
    );
  }
}
