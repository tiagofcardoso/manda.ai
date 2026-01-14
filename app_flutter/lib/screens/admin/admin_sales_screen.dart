import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../services/app_translations.dart';
import '../../constants/api.dart';

class AdminSalesScreen extends StatefulWidget {
  const AdminSalesScreen({super.key});

  @override
  State<AdminSalesScreen> createState() => _AdminSalesScreenState();
}

class _AdminSalesScreenState extends State<AdminSalesScreen> {
  String _selectedPeriod = 'daily';
  List<dynamic> _chartData = [];
  List<dynamic> _topProducts = [];
  bool _loading = true;

  // KPI Stats
  int _totalOrders = 0;
  double _totalRevenue = 0.0;
  double _avgTicket = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    await Future.wait([
      _fetchChartData(),
      _fetchStats(),
      _fetchTopProducts(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchChartData() async {
    try {
      final url = Uri.parse(
          '${ApiConstants.baseUrl}/admin/stats/sales?period=$_selectedPeriod');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) setState(() => _chartData = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error chart: $e');
    }
  }

  Future<void> _fetchTopProducts() async {
    try {
      final url =
          Uri.parse('${ApiConstants.baseUrl}/admin/stats/top_products?limit=5');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) setState(() => _topProducts = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error top products: $e');
    }
  }

  Future<void> _fetchStats() async {
    final supabase = Supabase.instance.client;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    final countResponse = await supabase
        .from('orders')
        .count(CountOption.exact)
        .gte('created_at', startOfDay);
    final response = await supabase
        .from('orders')
        .select('total_amount')
        .gte('created_at', startOfDay);

    double totalRevenue = 0.0;
    final List<dynamic> orders = response as List<dynamic>;
    for (var order in orders) {
      totalRevenue += (order['total_amount'] ?? 0.0);
    }

    if (mounted) {
      setState(() {
        _totalOrders = countResponse;
        _totalRevenue = totalRevenue;
        _avgTicket = _totalOrders > 0 ? _totalRevenue / _totalOrders : 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.titleMedium?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Teal Gradient Header Background
          Container(
            height: 350,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Custom App Bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          AppTranslations.of(context, 'salesActivity'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Three Gauges (KPIs)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildGaugeItem(
                            AppTranslations.of(context, 'orders').toUpperCase(),
                            _totalOrders.toString(),
                            _totalOrders / 50.0), // Mock max goal 50
                        _buildGaugeItem(
                            AppTranslations.of(context, 'revenue')
                                .toUpperCase(),
                            "€${_totalRevenue.toStringAsFixed(0)}",
                            (_totalRevenue / 500.0)
                                .clamp(0.0, 1.0)), // Mock max goal 500
                        _buildGaugeItem(
                            AppTranslations.of(context, 'avgTicket')
                                .toUpperCase(),
                            "€${_avgTicket.toStringAsFixed(1)}",
                            (_avgTicket / 20.0).clamp(0.0, 1.0)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 3. Floating Card Container
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      // Dynamic Card Color
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Products Title
                        Text(
                          AppTranslations.of(context, 'topProducts'),
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 10),

                        // Top Products Table
                        _buildTopProductsTable(),

                        const SizedBox(height: 30),

                        // Line Chart Title & Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppTranslations.of(context, 'salesTrend'),
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            _buildPeriodSelector(),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Line Chart
                        SizedBox(
                          height: 250,
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _chartData.isEmpty
                                  ? Center(
                                      child: Text(
                                          AppTranslations.of(context, 'noData'),
                                          style: TextStyle(color: textColor)))
                                  : LineChart(_mainLineData()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Gauge Widget Helper ---
  Widget _buildGaugeItem(String label, String value, double percent) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          width: 80,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: 135,
                  sectionsSpace: 0,
                  centerSpaceRadius: 30,
                  sections: [
                    PieChartSectionData(
                      color: Colors.white.withOpacity(0.3),
                      value: 100 - (percent * 100),
                      radius: 8,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      color: Colors.white,
                      value: percent * 100,
                      radius: 12,
                      showTitle: false,
                    ),
                    // Invisible section to make it a semi-circle gauge visual if needed,
                    // but full circle gauge looks fine too. Let's stick to full circle for simplicity of implementation.
                  ],
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  // --- Table Helper ---
  // --- Table Helper ---
  Widget _buildTopProductsTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    if (_loading) return const Center(child: LinearProgressIndicator());
    if (_topProducts.isEmpty)
      return Text(AppTranslations.of(context, 'noSalesYet'),
          style: TextStyle(color: textColor));

    return Column(
      children: _topProducts.asMap().entries.map((entry) {
        final index = entry.key;
        final product = entry.value;
        final isEven = index % 2 == 0;

        // Progress bar value
        final maxQty = _topProducts[0]['quantity'] as int;
        final currentQty = product['quantity'] as int;
        final progress = currentQty / (maxQty > 0 ? maxQty : 1);

        return Container(
          decoration: BoxDecoration(
              color: isEven
                  ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100])
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                  flex: 3,
                  child: Text(product['name'],
                      style: TextStyle(fontSize: 13, color: textColor))),
              Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      // Track background color
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[300],
                      color: index == 0
                          ? const Color(0xFF38ef7d)
                          : (index == 1 ? Colors.orangeAccent : Colors.amber),
                      minHeight: 8,
                    ),
                  )),
              const SizedBox(width: 8),
              Text(currentQty.toString(),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: textColor)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- Grid Data for Chart ---
  LineChartData _mainLineData() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodySmall?.color;

    final points = _chartData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble());
    }).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300],
            strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < _chartData.length) {
                // Show concise labels
                return Text(
                  _chartData[value.toInt()]['label'],
                  style: TextStyle(
                      color: textColor?.withOpacity(0.6), fontSize: 10),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: points,
          isCurved: true,
          gradient: const LinearGradient(
              colors: [Color(0xFF11998e), Color(0xFF38ef7d)]),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF11998e).withOpacity(0.3),
                const Color(0xFF38ef7d).withOpacity(0.0)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  // --- Period Selector Helper ---
  Widget _buildPeriodSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[200], // Dark/Light bg
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _periodBtn('daily', 'D', isDark),
          _periodBtn('weekly', 'W', isDark),
          _periodBtn('monthly', 'M', isDark),
        ],
      ),
    );
  }

  Widget _periodBtn(String key, String label, bool isDark) {
    bool isSelected = _selectedPeriod == key;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPeriod = key);
        _fetchChartData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF11998e) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            )),
      ),
    );
  }
}
