import 'package:chicagocrimes/visualization/getclassificationresults.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GetClassification extends StatefulWidget {
  @override
  _GetClassificationState createState() => _GetClassificationState();
}

class _GetClassificationState extends State<GetClassification> {
  int chartlenClassification = 0;
  late List<ChartSampleDataClassification> chartDataClassification;
  late Map<int, List<StatusMarker>> markersByStatus;
  late List<StatusMarker> markers;
  late GeoJsonParser geoJsonParser;
  List<Polygon> polygons = [];
  bool loadingdata = false;

  final Map<int, Color> statusColors = {
    0: Colors.red,
    1: Colors.blue,
  };

  @override
  // ignore: must_call_super
  void initState() {
    chartDataClassification = [];

    // Regenerate markers
    markers = [];
    for (ChartSampleDataClassification data in chartDataClassification) {
      int status = (data.prediction == data.label) ? 1 : 0;
      markers.add(StatusMarker(
          prediction: data.prediction,
          label: data.label,
          point: LatLng(data.latitude, data.longitude),
          child: Icon(
            Icons.location_on,
            color: statusColors[status] ?? Colors.black,
            size: 40,
          )));
    }

    // Divide markers based on cluster ID
    markersByStatus = {};
    for (var marker in markers) {
      markersByStatus.putIfAbsent(marker.status, () => []).add(marker);
    }
  }

  Future<void> fetchClassificationData() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8080/classification/predictions'));

      if (response.statusCode == 200) {
        // Decode the JSON into a list of ChartSampleData objects
        List<dynamic> jsonResponse = jsonDecode(response.body);
        setState(() {
          chartDataClassification = jsonResponse
              .map((data) => ChartSampleDataClassification.fromJson(data))
              .toList();
          chartlenClassification = chartDataClassification.length;

          // Regenerate markers
          markers = [];
          for (ChartSampleDataClassification data in chartDataClassification) {
            int status = (data.prediction == data.label) ? 1 : 0;
            markers.add(StatusMarker(
                prediction: data.prediction,
                label: data.label,
                point: LatLng(data.latitude, data.longitude),
                child: Icon(
                  Icons.location_on,
                  color: statusColors[status] ?? Colors.black,
                  size: 40,
                )));
          }

          // Divide markers based on cluster ID
          markersByStatus = {};
          for (var marker in markers) {
            markersByStatus.putIfAbsent(marker.status, () => []).add(marker);
          }
        });
        debugPrint("Data loaded successfully");
      } else {
        debugPrint("Error during loading: ${response.statusCode}");
        throw Exception('Failed to load clustering data');
      }
    } catch (e) {
      debugPrint("An error occurred: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Classification by Category, Community Area and Month'),
        backgroundColor: Colors.cyan,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(41.8781, -87.6298),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              for (var entry in markersByStatus.entries)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size: const Size(40, 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(50),
                    maxZoom: 15,
                    markers: entry.value,
                    builder: (context, markers) {
                      Color statusColor =
                          statusColors[entry.key] ?? Colors.black;

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: statusColor,
                        ),
                        child: Center(
                          child: Text(
                            markers.length.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, // Change the button color
                  ),
                  onPressed: () {
                    fetchClassificationData();
                  },
                  child: const Text("Get Classification predictions"),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow, // Change the button color
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GetClassificationResults(
                                data: chartDataClassification,
                              )),
                    );
                  },
                  child: const Text("Go to classification Chart"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//Class for the data we want to display
class ChartSampleDataClassification {
  final double latitude;
  final double longitude;

  final int prediction;
  final int label;

  ChartSampleDataClassification(
      this.latitude, this.longitude, this.prediction, this.label);

  // Method to create the ChartSampleData object from JSON
  factory ChartSampleDataClassification.fromJson(Map<String, dynamic> json) {
    return ChartSampleDataClassification(
        json['Latitude'],
        json['Longitude'],
        (json['Prediction'] as double).toInt(),
        (json['Label'] as double).toInt());
  }
}

// Class to contain the marker with a cluster ID
class StatusMarker extends Marker {
  final int prediction;
  final int label;
  final int status;

  const StatusMarker({
    required this.prediction,
    required this.label,
    required LatLng point,
    required Widget child,
  })  : status = (prediction == label) ? 1 : 0,
        super(
          width: 80.0,
          height: 80.0,
          point: point,
          child: child,
        );
}
