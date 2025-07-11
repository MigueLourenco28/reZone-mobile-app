// screens/activities_screen.dart
import '../utils/local_storage_util.dart';
import '../main.dart';
import 'community_screen.dart';
import 'activities_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(
          mainAxisAlignment:MainAxisAlignment.center,
          children: [
            Text(
              'Activities',
              style: TextStyle(
                fontFamily: 'Handler',
                fontSize: 45.0,
              ),
            ),
            Icon(
              Icons.landscape,
              size: 45.0,
            ),
          ]
      )),
      body: Center(child: Text('Activity content goes here')),
    );
  }
}