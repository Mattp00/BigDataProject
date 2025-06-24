import 'package:chicagocrimes/visualization/Screen.dart';
import 'package:chicagocrimes/visualization/dashboard.dart';
import 'package:chicagocrimes/visualization/drawer_list.dart';
import 'package:chicagocrimes/visualization/getClassification.dart';
import 'package:chicagocrimes/visualization/getClustering.dart';
import 'package:chicagocrimes/visualization/getCrimeDistributionPerYear.dart';
import 'package:chicagocrimes/visualization/getRegression.dart';
import 'package:chicagocrimes/visualization/postDomesticDistribution.dart';
import 'package:chicagocrimes/visualization/postLocationDistribution.dart';
import 'package:chicagocrimes/visualization/postTheftOver.dart';
import 'package:chicagocrimes/visualization/postTypeDistribution.dart';
import 'package:flutter/material.dart';

class DrawerMenu extends StatefulWidget {
  final Function notifyParent;

  DrawerMenu(this.notifyParent);

  @override
  DrawerMenuState createState() => DrawerMenuState();
}

class DrawerMenuState extends State<DrawerMenu> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          Container(
            padding: EdgeInsets.all(12.0),
            child: Image.asset("images/chicago_logo.jpg"),
          ),
          DrawerListTile(
              title: 'Homepage',
              svgSrc: 'icons/homepage.svg',
              tap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            Screen(page: DashboardContent())));
              }),
          DrawerListTile(
              title: 'Classification',
              svgSrc: 'icons/classification.svg',
              tap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            Screen(page: GetClassification())));
              }),
          DrawerListTile(
              title: 'Clustering',
              svgSrc: 'icons/clustering.svg',
              tap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            Screen(page: const GetClustering())));
              }),
          DrawerListTile(
              title: 'Regression',
              svgSrc: 'icons/linear-regression.svg',
              tap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => Screen(page: GetRegression())));
              }),
          DrawerListTile(
              title: 'Year distribution',
              svgSrc: 'icons/gaussian.svg',
              tap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => Screen(page: GetDistribution())));
              }),
          DrawerListTile(
              title: 'Domestic crimes',
              svgSrc: 'icons/gaussian.svg',
              tap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            Screen(page: PostDomesticDistribution())));
              }),
          DrawerListTile(
              title: 'Theft distribution',
              svgSrc: 'icons/gaussian.svg',
              tap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            Screen(page: PostTheftDistribution())));
              }),
          DrawerListTile(
              title: 'Location distribution',
              svgSrc: 'icons/gaussian.svg',
              tap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            Screen(page: PostLocationDistribution())));
              }),
          DrawerListTile(
              title: 'Type distribution',
              svgSrc: 'icons/gaussian.svg',
              tap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            Screen(page: PostTypeDistribution())));
              }),
        ],
      ),
    );
  }
}
