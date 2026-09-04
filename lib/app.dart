import 'package:flutter/material.dart';

class GrowthTrackApp extends StatelessWidget {
  const GrowthTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECCD GrowthTrack',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('ECCD GrowthTrack Initialized'),
        ),
      ),
    );
  }
}
