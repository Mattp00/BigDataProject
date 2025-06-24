import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GetClustering extends StatefulWidget {
  const GetClustering({Key? key}) : super(key: key);

  @override
  _GetClusteringState createState() => _GetClusteringState();
}

class _GetClusteringState extends State<GetClustering> {
  late List<ChartSampleData> chartData;
  late Map<int, List<ClusterMarker>> markersByCluster;
  late List<ClusterMarker> markers;
  int chartlen = 0;

  final Map<int, Color> clusterColors = {
    0: Colors.red,
    1: Colors.blue,
    2: Colors.green,
    3: Colors.black,
    4: Colors.white
  };

  @override
  void initState() {
    super.initState();
    chartData = [];
    markers = [];
    markersByCluster = {};
  }

  Future<void> fetchClusterData() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8080/cluster/predictions'));

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        setState(() {
          chartData = jsonResponse
              .map((data) => ChartSampleData.fromJson(data))
              .toList();
          chartlen = chartData.length;

          markers.clear();
          for (ChartSampleData data in chartData) {
            markers.add(ClusterMarker(
                clusterId: data.cluster,
                point: LatLng(data.latitude, data.longitude),
                child: Icon(
                  Icons.location_on,
                  color: clusterColors[data.cluster] ?? Colors.black,
                  size: 40,
                )));
          }

          markersByCluster.clear();
          for (var marker in markers) {
            markersByCluster
                .putIfAbsent(marker.clusterId, () => [])
                .add(marker);
          }
        });
      } else {
        debugPrint("Error during the data loading: ${response.statusCode}");
        throw Exception('Failed to load clustering data');
      }
    } catch (e) {
      debugPrint("A fatal error occurred: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clustering by location'),
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
              for (var entry in markersByCluster.entries)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size: const Size(40, 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(50),
                    maxZoom: 15,
                    markers: entry.value,
                    builder: (context, markers) {
                      Color clusterColor =
                          clusterColors[entry.key] ?? Colors.blue;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: clusterColor,
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
                )
            ],
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: fetchClusterData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Cambia il colore del pulsante
              ),
              child: const Text("Get Cluster Predictions"),
            ),
          ),
        ],
      ),
    );
  }
}

class ChartSampleData {
  final double latitude;
  final double longitude;
  final int cluster;

  ChartSampleData(this.latitude, this.longitude, this.cluster);

  factory ChartSampleData.fromJson(Map<String, dynamic> json) {
    return ChartSampleData(
      json['Latitude'],
      json['Longitude'],
      json['prediction'],
    );
  }
}

class ClusterMarker extends Marker {
  final int clusterId;

  const ClusterMarker({
    required this.clusterId,
    required LatLng point,
    required Widget child,
  }) : super(
          width: 80.0,
          height: 80.0,
          point: point,
          child: child,
        );
}
