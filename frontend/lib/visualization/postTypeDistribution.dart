import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;

class PostTypeDistribution extends StatefulWidget {
  @override
  _PostTypeDistributionState createState() => _PostTypeDistributionState();
}

class _PostTypeDistributionState extends State<PostTypeDistribution> {
  late List<TypeCrimes> typeDistributionInMonth;
  int chartlen = 0;
  int totalCrimes = 0;
  int month = 1;

  final Map<int, String> intMonth = {
    1: "January",
    2: "February",
    3: "March",
    4: "April",
    5: "May",
    6: "June",
    7: "July",
    8: "August",
    9: "September",
    10: "October",
    11: "November",
    12: "December",
  };

  @override
  void initState() {
    super.initState();
    typeDistributionInMonth = [];

    // Calcolo il totale dei crimini
    totalCrimes = typeDistributionInMonth.fold(
        0, (sum, crimeData) => sum + crimeData.crimes);

    chartlen = typeDistributionInMonth.length;
  }

  Future<void> postCrimeDistributionByMonth() async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/distributions/typeDistribution'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'month': month.toString(),
        }),
      );
      //print("Response: ${response.body}");
      if (response.statusCode == 200) {
        //print("Response: ${response.body}");
        List<dynamic> jsonResponse = jsonDecode(response.body);
        setState(() {
          typeDistributionInMonth =
              jsonResponse.map((data) => TypeCrimes.fromJson(data)).toList();

          totalCrimes = typeDistributionInMonth.fold(
              0, (sum, crimeData) => sum + crimeData.crimes);
          chartlen = typeDistributionInMonth.length;
        });
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("A fatal error occurred: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(
              "Primary type distribution for the selected month ${intMonth[month]}"),
        ),
        body: Column(
          children: [
            Expanded(
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                // Absolute crimes
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Crimes numbers'),
                ),
                // Normalized crimes
                axes: <ChartAxis>[
                  NumericAxis(
                    name: 'normalizedAxis',
                    title: AxisTitle(text: 'Normalized Crimes numbers'),
                    opposedPosition: true,
                  )
                ],
                title: ChartTitle(
                    text:
                        'Typology distribution for the selected month ${intMonth[month]}'),
                legend: Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<TypeCrimes, String>(
                    dataSource: typeDistributionInMonth,
                    xValueMapper: (TypeCrimes result, _) => result.type,
                    yValueMapper: (TypeCrimes result, _) => result.crimes,
                    name: 'Crimes numbers',
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                  ),
                  LineSeries<TypeCrimes, String>(
                    dataSource: typeDistributionInMonth,
                    xValueMapper: (TypeCrimes result, _) => result.type,
                    yValueMapper: (TypeCrimes result, _) =>
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
                postCrimeDistributionByMonth();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: Text("Get Data"),
            ),
            SizedBox(height: 20),
            DropdownButton<int>(
              value: month,
              items: const [
                DropdownMenuItem(value: 1, child: Text('January')),
                DropdownMenuItem(value: 2, child: Text('February')),
                DropdownMenuItem(value: 3, child: Text('March')),
                DropdownMenuItem(value: 4, child: Text('April')),
                DropdownMenuItem(value: 5, child: Text('May')),
                DropdownMenuItem(value: 6, child: Text('June')),
                DropdownMenuItem(value: 7, child: Text('July')),
                DropdownMenuItem(value: 8, child: Text('August')),
                DropdownMenuItem(value: 9, child: Text('September')),
                DropdownMenuItem(value: 10, child: Text('October')),
                DropdownMenuItem(value: 11, child: Text('November')),
                DropdownMenuItem(value: 12, child: Text('December')),
              ],
              onChanged: (value) {
                setState(() {
                  month = value!;
                });
              },
            ),
          ],
        ));
  }
}

class TypeCrimes {
  final String type;
  final int crimes;

  TypeCrimes(this.type, this.crimes);

  // JSON creation
  factory TypeCrimes.fromJson(Map<String, dynamic> json) {
    return TypeCrimes(json['Category'], json['Crimes']);
  }
}
