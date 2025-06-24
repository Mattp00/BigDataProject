import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;

class GetDistribution extends StatefulWidget {
  @override
  _GetDistributionState createState() => _GetDistributionState();
}

class _GetDistributionState extends State<GetDistribution> {
  late List<CrimesPerYear> crimesDistributionPerYear;
  int chartlen = 0;
  int totalCrimes = 0;

  @override
  void initState() {
    super.initState();
    crimesDistributionPerYear = [];

    // Total crimes initialization
    totalCrimes = crimesDistributionPerYear.fold(
        0, (sum, crimeData) => sum + crimeData.crimes);

    chartlen = crimesDistributionPerYear.length;
  }

  Future<void> fetchDistributionData() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8080/distributions/crimesPerYear'));

      debugPrint(response.body);
      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        setState(() {
          crimesDistributionPerYear =
              jsonResponse.map((data) => CrimesPerYear.fromJson(data)).toList();
          // Total crimes sum
          totalCrimes = crimesDistributionPerYear.fold(
              0, (sum, crimeData) => sum + crimeData.crimes);
          chartlen = crimesDistributionPerYear.length;
        });

        debugPrint("The data were loaded successfully");
      } else {
        debugPrint("Error during data loading: ${response.statusCode}");
        throw Exception('Failed to load distribution data');
      }
    } catch (e) {
      debugPrint("A fatal error occurred: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text("Crime distribution per year"),
        ),
        body: Column(
          children: [
            Expanded(
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                // Y1-axis => Absolute crimes
                primaryYAxis: const NumericAxis(
                  title: AxisTitle(text: 'Crimes number'),
                ),
                // Y2-axis => normalized crimes
                axes: const <ChartAxis>[
                  NumericAxis(
                    name: 'normalizedAxis',
                    title: AxisTitle(text: 'Normalized crimes'),
                    opposedPosition: true,
                  )
                ],
                title: const ChartTitle(text: 'Crimes distribution per year'),
                legend: const Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<CrimesPerYear, int>(
                    dataSource: crimesDistributionPerYear,
                    xValueMapper: (CrimesPerYear result, _) => result.year,
                    yValueMapper: (CrimesPerYear result, _) => result.crimes,
                    name: 'Crimes number',
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                  ),
                  LineSeries<CrimesPerYear, int>(
                    dataSource: crimesDistributionPerYear,
                    xValueMapper: (CrimesPerYear result, _) => result.year,
                    yValueMapper: (CrimesPerYear result, _) =>
                        result.crimes / totalCrimes,
                    name: 'Normalized curve',
                    markerSettings: MarkerSettings(isVisible: true),
                    dataLabelSettings: DataLabelSettings(isVisible: false),
                    yAxisName: 'normalizedAxis',
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                fetchDistributionData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Change button's color
              ),
              child: Text("Get Data"),
            ),
            SizedBox(height: 20),
          ],
        ));
  }
}

class CrimesPerYear {
  final int year;
  final int crimes;

  CrimesPerYear(this.year, this.crimes);

  // Create crimes per year from json
  factory CrimesPerYear.fromJson(Map<String, dynamic> json) {
    return CrimesPerYear(json['Year'], json['Crimes']);
  }
}
