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
  final String tokenID, userID;
  final VoidCallback onLogoutSuccess;
  const MapScreen({super.key, required this.tokenID, required this.userID, required this.onLogoutSuccess});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  bool isActivitiesMenuOpen = false;
  bool isLoading = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  MapType currentMapType = MapType.normal;
  bool isMapTypeMenuOpen = false;
  IconData currentMapIcon = Icons.layers; // Default icon
  Set<String> userActivityPlaces = {};

  GoogleMapController? mapController;
  Set<Polygon> polygons = {};
  LatLng? selectedPoint;
  String selectedActivityType = '';
  String? selectedActivityIcon; // holds SVG path

  @override
  void initState() {
    super.initState();
    checkTokenExp();
    loadUserActivities();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(_fadeAnimation);
  }

  Future<void> loadUserActivities() async {
    try {
      final res = await http.get(
        Uri.parse("https://rezone-459910.oa.r.appspot.com/activities/list"),
        headers: {'Authorization': 'Bearer ${widget.tokenID}'},
      );

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final Set<String> places = data.map<String>((act) => act['activityPlace']?.toString() ?? "").toSet();
        setState(() => userActivityPlaces = places);
      } else {
        debugPrint("Failed to load activities: ${res.body}");
      }
    } catch (e) {
      debugPrint("Error loading activities: $e");
    }
  }

  void checkTokenExp() async {
    // Check if the token is still valid, if not, redirect to login page;m
    void checkToken() async {
      final authData = await LocalStorageUtil.getAuthData();
      final tokenExp = authData['tokenExp'];

      if (tokenExp == null) {
        // No expiration info, redirect to login
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      final expiration = int.tryParse(tokenExp);
      if (expiration == null) {
        Navigator.pushReplacementNamed(context, '/');
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now >= expiration) {
        widget.onLogoutSuccess();
      }
    }
  }

  void toggleActivitiesMenu() {
    setState(() => isActivitiesMenuOpen = !isActivitiesMenuOpen);
    isActivitiesMenuOpen ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  LatLngBounds _computeBounds(List<LatLng> points) {
    final southwestLat = points.map((p) => p.latitude).reduce(min);
    final southwestLng = points.map((p) => p.longitude).reduce(min);
    final northeastLat = points.map((p) => p.latitude).reduce(max);
    final northeastLng = points.map((p) => p.longitude).reduce(max);

    return LatLngBounds(
      southwest: LatLng(southwestLat, southwestLng),
      northeast: LatLng(northeastLat, northeastLng),
    );
  }

  LatLng calculateCentroid(List<LatLng> points) { // Save polygon as coordinates
    double latitudeSum = 0;
    double longitudeSum = 0;

    for (var point in points) {
      latitudeSum += point.latitude;
      longitudeSum += point.longitude;
    }

    return LatLng(
      latitudeSum / points.length,
      longitudeSum / points.length,
    );
  }

  // Dummy function to fetch polygons
  Future<void> fetchPolygons({required bool recent}) async {
    try {
      final response = await http.get(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/worksheet/'),
        headers: {'Authorization': 'Bearer ${widget.tokenID}'},
      );

      if (response.statusCode != 200) {
        throw Exception("Status: ${response.statusCode}, Body: ${response.body}");
      }

      final List<dynamic> worksheets = jsonDecode(response.body);

      if (worksheets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nenhuma folha de obra disponível.")));
        return;
      }

      List<Map<String, dynamic>> detailedWorksheets = [];

      for (final ws in worksheets) {
        final id = ws['id'];
        if (id == null) continue;

        final detailRes = await http.post(
          Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/worksheet/detailed'),
          headers: {
            'Authorization': 'Bearer ${widget.tokenID}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({"id": id}),
        );

        if (detailRes.statusCode != 200) continue;

        final detailData = jsonDecode(detailRes.body);
        if (detailData['WorkSheet']?['workSheet_issue_date'] == null ||
            detailData['Features'] == null) continue;

        detailedWorksheets.add({
          "id": id,
          "issue_date": detailData['WorkSheet']['workSheet_issue_date'],
          "features": detailData['Features'],
        });
      }

      if (detailedWorksheets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nenhuma folha com detalhes válidos.")));
        return;
      }

      // Sort and take oldest/recent
      detailedWorksheets.sort((a, b) {
        final aDate = DateTime.tryParse(a['issue_date']) ?? DateTime(1900);
        final bDate = DateTime.tryParse(b['issue_date']) ?? DateTime(1900);
        return aDate.compareTo(bDate);
      });

      final selected = recent ? detailedWorksheets.reversed.take(3) : detailedWorksheets.take(3);

      Set<Polygon> newPolygons = {};
      List<LatLng> allPoints = [];

      for (final ws in selected) {
        final features = ws['features'] as List;

        for (final f in features) {
          final polygonId = f['feature_polygon_id'].toString();
          final coords = f['feature_coordinates'];

          if (coords == null || coords.length < 6) continue;

          final latlngList = <LatLng>[];
          for (int i = 0; i < coords.length - 1; i += 2) {
            final x = coords[i];
            final y = coords[i + 1];

            final lat = 39.5 + (y / 1e5);
            final lng = -8.0 + (x / 1e5);

            latlngList.add(LatLng(lat, lng));
          }

          // Ensure it closes
          if (latlngList.first != latlngList.last) {
            latlngList.add(latlngList.first);
          }

          LatLng centroid = calculateCentroid(latlngList);
          String placeKey = "${centroid.latitude},${centroid.longitude}";

          // Choose polygon color
          final bool hasActivity = userActivityPlaces.contains(placeKey);

          newPolygons.add(
            Polygon(
              polygonId: PolygonId(polygonId),
              points: latlngList,
              strokeColor: hasActivity ? Colors.green[800]! : Colors.blue[800]!,
              fillColor: hasActivity
                  ? Colors.green.withOpacity(0.25)
                  : Colors.blue.withOpacity(0.2),
              strokeWidth: 3,
              consumeTapEvents: true,
              onTap: () => onPolygonSelected(polygonId, placeKey),
            ),
          );

          allPoints.addAll(latlngList);
        }
      }

      setState(() => polygons = newPolygons);

      if (allPoints.isNotEmpty && mapController != null) {
        LatLngBounds bounds = _computeBounds(allPoints);

        mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50), // 50 = padding
        );
      }

      if (newPolygons.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nenhum polígono encontrado.")));
      }

    } catch (e) {
      debugPrint("Erro em fetchPolygons: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao buscar folhas: $e")));
    }
  }

  void onPolygonSelected(String polygonId, String polygonCenter) {
    selectedPoint = null;

    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController friendController = TextEditingController();
        final TextEditingController dateController = TextEditingController();
        final TextEditingController timeController = TextEditingController();

        return AlertDialog(
          title: const Text("Create Activity"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Polygon selected: $polygonId"),
              TextField(controller: friendController, decoration: InputDecoration(labelText: "Friend name")),
              TextField(controller: dateController, decoration: InputDecoration(labelText: "Date (DD/MM/YYYY)")),
              TextField(controller: timeController, decoration: InputDecoration(labelText: "Hour (HH:MM)")),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {

                final body = {
                  "username": widget.userID,
                  "friendUserName": friendController.text,
                  "activityType": selectedActivityType,
                  "activityDate": dateController.text,
                  "activityTime": timeController.text,
                  "activityPlace": polygonCenter,
                };

                try {

                  final res = await http.post(
                    Uri.parse("https://rezone-459910.oa.r.appspot.com/rest/activities/"),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer ${widget.tokenID}',
                    },
                    body: jsonEncode(body),
                  );

                  if (res.statusCode == 200) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Activity created!')));
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res.body}')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error fetching creating activity: $e")),
                  );
                }
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapTypeButton({
    required IconData icon,
    required MapType type,
    required String tooltip,
  }) {
    return FloatingActionButton(
      heroTag: 'mapType_$type',
      backgroundColor: Colors.blue,
      mini: false,
      tooltip: tooltip,
      onPressed: () {
        setState(() {
          currentMapType = type;
          isMapTypeMenuOpen = false;
          currentMapIcon = icon;
        });
      },
      child: Icon(icon, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    const LatLng _center = LatLng(39.556664, -7.995860); // Mação

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(target: _center, zoom: 13),
            polygons: polygons,
            mapType: currentMapType,
          ),

          if (isLoading)
              Container(
                color: Colors.black.withOpacity(0.4),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
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
                  onPressed: toggleActivitiesMenu,
                  backgroundColor: Colors.green,
                  child: isActivitiesMenuOpen
                      ? const Icon(Icons.close, color: Colors.white)
                      : (selectedActivityIcon != null
                      ? SvgPicture.asset(selectedActivityIcon!, width: 24, height: 24, color: Colors.white)
                      : const Icon(Icons.menu, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                if (isActivitiesMenuOpen) // TODO: add animation + make icon color match dark/light mode
                  Column(
                    children: [
                      _buildMenuButton(
                          svgIconPath: 'assets/icons/camping.svg',
                          tag: 'camping',
                          activityType: 'CAMPING',
                          onPressed: () async {
                            // TODO: Filter worksheets by the oldest date and replace the map
                            // with the polygons of the worksheets that were created the oldest
                            setState(() {
                              selectedActivityType = "CAMPING";
                              selectedActivityIcon = 'assets/icons/camping.svg';
                              isActivitiesMenuOpen = false;
                              isLoading = true;
                            });
                            await fetchPolygons(recent: true);
                            setState(() => isLoading = false);
                          }),
                      const SizedBox(height: 8),
                      _buildMenuButton(
                          svgIconPath: 'assets/icons/footprint.svg',
                          tag: 'jogging',
                          activityType: 'JOGGING',
                          onPressed: () async {
                            // TODO: Filter worksheets by the most recent date and replace the map
                            // with the polygons of the worksheets that were created the most recently
                            setState(() {
                              selectedActivityType = "JOGGING";
                              selectedActivityIcon = 'assets/icons/footprint.svg';
                              isActivitiesMenuOpen = false;
                              isLoading = true;
                            });
                            await fetchPolygons(recent: false);
                            setState(() => isLoading = false);
                          }),
                      const SizedBox(height: 8),
                      _buildMenuButton(
                          svgIconPath: 'assets/icons/hiking.svg',
                          tag: 'mountain',
                          activityType: 'CLIMBING',
                          onPressed: () async {
                            //TODO:
                          }),
                    ],
                  )
              ],
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Toggle button
                FloatingActionButton(
                  heroTag: 'mapTypeToggle',
                  backgroundColor: Colors.blue,
                  onPressed: () {
                    setState(() => isMapTypeMenuOpen = !isMapTypeMenuOpen);
                  },
                  child: Icon(
                    isMapTypeMenuOpen ? Icons.close : currentMapIcon,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                // Menu buttons
                if (isMapTypeMenuOpen)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildMapTypeButton(
                        icon: Icons.map,
                        type: MapType.normal,
                        tooltip: "Normal Map",
                      ),
                      const SizedBox(height: 8),
                      _buildMapTypeButton(
                        icon: Icons.satellite_alt,
                        type: MapType.satellite,
                        tooltip: "Satellite",
                      ),
                      const SizedBox(height: 8),
                      _buildMapTypeButton(
                        icon: Icons.terrain,
                        type: MapType.terrain,
                        tooltip: "Terrain",
                      ),
                      const SizedBox(height: 8),
                      _buildMapTypeButton(
                        icon: Icons.layers,
                        type: MapType.hybrid,
                        tooltip: "Hybrid",
                      ),
                    ],
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    String? svgIconPath,
    IconData? iconData,
    required String tag,
    required String activityType,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton(
      heroTag: tag,
      backgroundColor: selectedActivityType == activityType ? Colors.blue : Colors.green,
      onPressed: onPressed,
      child: svgIconPath != null
          ? SvgPicture.asset(svgIconPath, width: 24, height: 24, color: Colors.white)
          : Icon(iconData, color: Colors.white),
    );
  }
}