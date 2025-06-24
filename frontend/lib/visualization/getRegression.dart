import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GetRegression extends StatefulWidget {
  @override
  _GetRegressionState createState() => _GetRegressionState();
}

class _GetRegressionState extends State<GetRegression> {
  late List<IncomeCrimes> chartDataRegression;
  int chartlen = 0;

  @override
  void initState() {
    super.initState();
    chartDataRegression = [];
    chartlen = chartDataRegression.length;

    // fetchRegressionData();
  }

  Future<void> fetchRegressionData() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8080/regression/predictions'));

      debugPrint(response.body);
      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        setState(() {
          chartDataRegression =
              jsonResponse.map((data) => IncomeCrimes.fromJson(data)).toList();
          chartlen = chartDataRegression.length;
        });

        debugPrint("The data were loaded successfully");
      } else {
        debugPrint("Error during data loading: ${response.statusCode}");
        throw Exception('Failed to load regression data');
      }
    } catch (e) {
      debugPrint("A fatal error occurred: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    List<IncomeCrimes> regressionLineData = [];
    if (chartDataRegression.isNotEmpty) {
      final double coefficient = chartDataRegression[0].Coefficient;
      final double intercept = chartDataRegression[0].Intercept;

      // USe the data to create a regression line
      double minPCI = chartDataRegression
          .map((data) => data.PCI)
          .reduce((a, b) => a < b ? a : b);
      double maxPCI = chartDataRegression
          .map((data) => data.PCI)
          .reduce((a, b) => a > b ? a : b);

      regressionLineData.add(
        IncomeCrimes(
          minPCI,
          coefficient * minPCI + intercept,
          coefficient,
          intercept,
        ),
      );
      regressionLineData.add(
        IncomeCrimes(
          maxPCI,
          coefficient * maxPCI + intercept,
          coefficient,
          intercept,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Regression by income"),
        backgroundColor: Colors.cyan,
      ),
      body: Column(
        children: [
          Expanded(
            child: SfCartesianChart(
              title: const ChartTitle(text: "Scatter plot Regression"),
              zoomPanBehavior: ZoomPanBehavior(
                  enablePinching: true,
                  enablePanning: true,
                  enableMouseWheelZooming: true,
                  enableSelectionZooming: true,
                  zoomMode: ZoomMode.xy),
              primaryXAxis: const NumericAxis(
                title: AxisTitle(text: "IncomePerCapita"),
              ),
              primaryYAxis: const NumericAxis(
                title: AxisTitle(text: "CrimesPerCapita"),
              ),
              series: <CartesianSeries<dynamic, dynamic>>[
                ScatterSeries<IncomeCrimes, double>(
                  dataSource: chartDataRegression,
                  xValueMapper: (IncomeCrimes data, _) => data.PCI,
                  yValueMapper: (IncomeCrimes data, _) => data.CrimesPerCapita,
                  markerSettings: const MarkerSettings(isVisible: true),
                ),
                if (regressionLineData.isNotEmpty)
                  LineSeries<IncomeCrimes, double>(
                    dataSource: regressionLineData,
                    xValueMapper: (IncomeCrimes data, _) => data.PCI,
                    yValueMapper: (IncomeCrimes data, _) =>
                        data.CrimesPerCapita,
                    color: Colors.red,
                    width: 2,
                    name: 'Regression Line',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              fetchRegressionData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text("Get Regression data"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class IncomeCrimes {
  final double PCI;
  final double CrimesPerCapita;
  final double Coefficient;
  final double Intercept;

  IncomeCrimes(
      this.PCI, this.CrimesPerCapita, this.Coefficient, this.Intercept);

  factory IncomeCrimes.fromJson(Map<String, dynamic> json) {
    return IncomeCrimes(
      json['PCI'].toDouble(),
      json['Crimes'].toDouble(),
      json['Coefficient'].toDouble(),
      json['Intercept'].toDouble(),
    );
  }
}
