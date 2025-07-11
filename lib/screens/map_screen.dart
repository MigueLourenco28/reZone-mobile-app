// screens/map_screen.dart
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

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  bool isMenuOpen = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(_fadeAnimation);
  }

  void toggleMenu() {
    setState(() => isMenuOpen = !isMenuOpen);
    isMenuOpen ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const LatLng _center = LatLng(39.556664, -7.995860); // Mação

    return Scaffold(
      body: Stack(
        children: [
          const GoogleMap( // Display Google Maps
            initialCameraPosition: CameraPosition(target: _center, zoom: 13),
          ),

          // Menu Toggle + Animated Menu (no blur)
          Positioned(
            top: 40,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FloatingActionButton(
                  heroTag: 'menuToggle',
                  onPressed: toggleMenu,
                  child: Icon(
                    isMenuOpen ? Icons.close : Icons.menu,
                  ),
                ),
                const SizedBox(height: 12),
                if (isMenuOpen) // TODO: add animation + make icon color match dark/light mode
                  Column(
                    children: [
                      _buildMenuButton(svgIconPath: 'assets/icons/camping.svg', tag: 'camping', onPressed: () {}),
                      const SizedBox(height: 8),
                      _buildMenuButton(svgIconPath: 'assets/icons/footprint.svg', tag: 'jogging', onPressed: () {}),
                      const SizedBox(height: 8),
                      _buildMenuButton(svgIconPath: 'assets/icons/hiking.svg', tag: 'mountain', onPressed: () {}),
                    ],
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    String? svgIconPath,
    IconData? iconData,
    required String tag,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton(
      heroTag: tag,
      backgroundColor: Colors.green,
      onPressed: onPressed,
      child: svgIconPath != null
          ? SvgPicture.asset(svgIconPath, width: 24, height: 24, color: Colors.white)
          : Icon(iconData, color: Colors.white),
    );
  }
}