import 'package:chicagocrimes/support/controller.dart';
import 'package:chicagocrimes/visualization/Screen.dart';
import 'package:chicagocrimes/visualization/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chicago Crimes Big Data Project',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => Controller(),
          )
        ],
        child: Screen(page: DashboardContent()),
      ),
    );
  }
}
