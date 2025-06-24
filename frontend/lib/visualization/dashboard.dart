import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Expanded(
          child: Text(
            "Welcome on the Chicago crimes homepage",
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 40,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 5,
          child: Image.asset("images/chicago_logo.jpg"),
        )
      ]),
    );
  }
}
