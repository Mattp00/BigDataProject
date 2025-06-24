import 'package:chicagocrimes/visualization/drawer_menu.dart';
import 'package:flutter/material.dart';

class Screen extends StatefulWidget {
  final Widget page;
  Screen({Key? key, required this.page}) : super(key: key);
  @override
  ScreenState createState() => ScreenState();
}

class ScreenState extends State<Screen> {
  late Widget currentPage;
  @override
  void initState() {
    super.initState();
    currentPage = this.widget.page;
  }

  updateIndexMenu(Widget newPage) {
    setState(() {
      currentPage = newPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerMenu(updateIndexMenu),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //if (Responsive.isDesktop(context))
            Expanded(
              child: DrawerMenu(updateIndexMenu),
            ),
            Expanded(
              flex: 5,
              child: currentPage,
            )
          ],
        ),
      ),
    );
  }
}
