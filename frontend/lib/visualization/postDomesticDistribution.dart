import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;

class PostDomesticDistribution extends StatefulWidget {
  @override
  _PostDomesticDistributionState createState() =>
      _PostDomesticDistributionState();
}

class _PostDomesticDistributionState extends State<PostDomesticDistribution> {
  late List<DomesticCrimes> domesticCrimesInCommunityArea;
  int chartlen = 0;
  int totalCrimes = 0;
  int communityArea = 1;
  List<String> communityAreas = [
    "Rogers Park",
    "West Ridge",
    "Uptown",
    "Lincoln Square",
    "North Center",
    "Lake View",
    "Lincoln Park",
    "Near North Side",
    "Edison Park",
    "Norwood Park",
    "Jefferson Park",
    "Forest Glen",
    "North Park",
    "Albany Park",
    "Portage Park",
    "Irving Park",
    "Dunning",
    "Montclare",
    "Belmont Cragin",
    "Hermosa",
    "Avondale",
    "Logan Square",
    "Humboldt Park",
    "West Town",
    "Austin",
    "West Garfield Park",
    "East Garfield Park",
    "Near West Side",
    "North Lawndale",
    "South Lawndale",
    "Lower West Side",
    "Loop",
    "Near South Side",
    "Armour Square",
    "Douglas",
    "Oakland",
    "Fuller Park",
    "Grand Boulevard",
    "Kenwood",
    "Washington Park",
    "Hyde Park",
    "Woodlawn",
    "South Shore",
    "Chatham",
    "Avalon Park",
    "South Chicago",
    "Burnside",
    "Calumet Heights",
    "Roseland",
    "Pullman",
    "South Deering",
    "East Side",
    "West Pullman",
    "Riverdale",
    "Hegewisch",
    "Garfield Ridge",
    "Archer Heights",
    "Brighton Park",
    "McKinley Park",
    "Bridgeport",
    "New City",
    "West Elsdon",
    "Gage Park",
    "Clearing",
    "West Lawn",
    "Chicago Lawn",
    "West Englewood",
    "Englewood",
    "Greater Grand Crossing",
    "Ashburn",
    "Auburn Gresham",
    "Beverly",
    "Washington Heights",
    "Mount Greenwood",
    "Morgan Park",
    "O'Hare",
    "Edgewater"
  ];

  @override
  void initState() {
    super.initState();
    domesticCrimesInCommunityArea = [];

    totalCrimes = domesticCrimesInCommunityArea.fold(
        0, (sum, crimeData) => sum + crimeData.crimes);

    chartlen = domesticCrimesInCommunityArea.length;
  }

  Future<void> postCrimeDistributionByMonth() async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/distributions/domesticDistribution'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'community-area': communityArea.toString(),
        }),
      );

      if (response.statusCode == 200) {
        //print("Risposta: ${response.body}"
        List<dynamic> jsonResponse = jsonDecode(response.body);
        setState(() {
          domesticCrimesInCommunityArea = jsonResponse
              .map((data) => DomesticCrimes.fromJson(data))
              .toList();

          totalCrimes = domesticCrimesInCommunityArea.fold(
              0, (sum, crimeData) => sum + crimeData.crimes);
          chartlen = domesticCrimesInCommunityArea.length;
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
          title: Text("Domestic Crimes in the selected community area"),
        ),
        body: Column(
          children: [
            Expanded(
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Crimes numbers'),
                ),
                axes: <ChartAxis>[
                  NumericAxis(
                    name: 'normalizedAxis',
                    title: AxisTitle(text: 'Normalized crimes numbers'),
                    opposedPosition: true,
                  )
                ],
                title: ChartTitle(
                    text:
                        'Crimes distribution for the community area: ${communityAreas[communityArea - 1]}'),
                legend: Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<DomesticCrimes, String>(
                    dataSource: domesticCrimesInCommunityArea,
                    xValueMapper: (DomesticCrimes result, _) => result.type,
                    yValueMapper: (DomesticCrimes result, _) => result.crimes,
                    name: 'Crimes number',
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                  ),
                  LineSeries<DomesticCrimes, String>(
                    dataSource: domesticCrimesInCommunityArea,
                    xValueMapper: (DomesticCrimes result, _) => result.type,
                    yValueMapper: (DomesticCrimes result, _) =>
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
              value: communityArea,
              items: communityAreas.map((area) {
                return DropdownMenuItem<int>(
                  value: communityAreas.indexOf(area) + 1, // Valore da 1 a 77
                  child: Text(area),
                );
              }).toList(),
              onChanged: (int? newValue) {
                setState(() {
                  communityArea = newValue!;
                });
              },
            ),
          ],
        ));
  }
}

class DomesticCrimes {
  final String type;
  final int crimes;

  DomesticCrimes(this.type, this.crimes);

  // JSON CREATION
  factory DomesticCrimes.fromJson(Map<String, dynamic> json) {
    return DomesticCrimes(
        json['Domestic'] == true ? 'Domestic' : 'Non-domestic', json['Crimes']);
  }
}
