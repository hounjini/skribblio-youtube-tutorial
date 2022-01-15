import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'paint_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  Map<String, String> data = {
    "nickname": "hounjini",
    "name": "room here",
    "occupancy": "10",
    "maxRounds": "10",
  };
  //state object는 이미 context를 가지고 있음.

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skribbl Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PaintScreen(data: data, screenFrom: 'createRoom'),
    );
  }
}
