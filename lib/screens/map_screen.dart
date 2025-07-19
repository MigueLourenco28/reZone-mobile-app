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


import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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

  String? userRole;
  bool get isPO => userRole == "PO";
  bool isWorksheetSidebarOpen = false;
  Map<String, dynamic>? selectedWorksheetDetails;

  bool isTaskSidebarOpen = false;
  List<Map<String, dynamic>> myTasks = [];

  @override
  void initState() {
    super.initState();

    checkTokenExp();
    final payload = Jwt.parseJwt(widget.tokenID);
    userRole = payload['role'];

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
    // Check if the token is still valid, if not, redirect to login page;
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
    if (now >= expiration) widget.onLogoutSuccess();
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

  Future<void> drawMyTaskPolygons() async {
    try {
      final res = await http.get(
        Uri.parse("https://rezone-459910.oa.r.appspot.com/rest/execution/mytasks"),
        headers: {'Authorization': 'Bearer ${widget.tokenID}'},
      );

      if (res.statusCode != 200) throw Exception("Erro ao buscar tarefas");
      final List<Map<String, dynamic>> tasks = List<Map<String, dynamic>>.from(
          jsonDecode(res.body)
      );
      Set<Polygon> newPolygons = {};
      List<LatLng> allPoints = [];

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

      for (final task in tasks) {
        // Obter o polígono associado à tarefa
        // Contruír o polígono no mapa através do id do poligono na worksheet e folha de execução
        // Se a tarefa ja foi concluida o polígono aparece verde
        // Se não foi concluida o polígono aparece azul e, quando o user clica nela, aparece o forms a ser completo
        // Usar a função _fetchPolygons como exemplo
        final executionWorkSheetId = task['id'].split("_")[0];
        // Get detailed worksheet info

        final isCompleted = task['status'] == 'COMPLETED';

        Map<String, dynamic> detailedWorksheet = {};

        for (final ws in worksheets) {
          final id = ws['id'];
          if (id != executionWorkSheetId) continue;

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

          detailedWorksheet = {
            "id": id,
            "issue_date": detailData['WorkSheet']['workSheet_issue_date'],
            "features": detailData['Features'],
          };
        }

        if (detailedWorksheet.isEmpty || detailedWorksheet['features'] == null) continue;

        final features = detailedWorksheet['features'] as List;

        final taskPolygonId = task['polygonId'].toString();

        for (final f in features) {
          final polygonId = f['feature_polygon_id'].toString();
          if(polygonId != taskPolygonId) continue;
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

          allPoints.addAll(latlngList);

          newPolygons.add(
            Polygon(
              polygonId: PolygonId("task_$polygonId"),
              points: latlngList,
              strokeColor: isCompleted ? Colors.green[800]! : Colors.blue[800]!,
              fillColor: isCompleted
                  ? Colors.green.withOpacity(0.25)
                  : Colors.blue.withOpacity(0.2),
              strokeWidth: 3,
              consumeTapEvents: true,
              onTap: () {
                if (!isCompleted) _openTaskForm(task);
                else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Task already completed.")));
              },
            ),
          );
        }
      }

      setState(() {
        polygons = newPolygons;
        myTasks = tasks;
      });

      if (newPolygons.isNotEmpty && mapController != null) {
        final allPoints = newPolygons.expand((p) => p.points).toList();
        final bounds = _computeBounds(allPoints);
        mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nenhuma tarefa encontrada.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao desenhar tarefas: $e")));
    }
  }

  void _openTaskForm(Map<String, dynamic> task) {
    final descController = TextEditingController();
    final areaController = TextEditingController();
    final obsController = TextEditingController();
    bool isCompleted = false;
    List<XFile> photos = [];
    PlatformFile? gpxFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tarefa: ${task['operationCode']} (Polígono ${task['polygonId']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                TextField(controller: descController, decoration: const InputDecoration(labelText: "Descrição da Atividade")),
                TextField(controller: areaController, decoration: const InputDecoration(labelText: "Área (ha)"), keyboardType: TextInputType.number),
                TextField(controller: obsController, decoration: const InputDecoration(labelText: "Observações")),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickMultiImage();
                    if (picked.isNotEmpty) {
                      setState(() => photos = picked);
                    }
                  },
                  child: const Text("Selecionar Fotos"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['gpx']);
                    if (picked != null) {
                      setState(() => gpxFile = picked.files.first);
                    }
                  },
                  child: const Text("Selecionar Ficheiro GPX"),
                ),
                Row(
                  children: [
                    Checkbox(value: isCompleted, onChanged: (v) => setState(() => isCompleted = v ?? false)),
                    const Text("Marcar como concluída")
                  ],
                ),
                ElevatedButton(
                    onPressed: () async {
                      List<String> base64Photos = [];
                      for (final xfile in photos) {
                        final bytes = await xfile.readAsBytes();
                        base64Photos.add("data:image/jpeg;base64,${base64Encode(bytes)}");
                      }
                      String? gpxContent;
                      if (gpxFile != null) gpxContent = utf8.decode(gpxFile!.bytes!);

                      final body = {
                        "executionTaskId": task['id'],
                        "activityDescription": descController.text,
                        "areaHa": double.tryParse(areaController.text) ?? 0,
                        "observations": obsController.text,
                        "photos": base64Photos,
                        "gpsTrack": gpxContent ?? "",
                        "markTaskAsCompleted": isCompleted
                      };

                      final res = await http.post(
                        Uri.parse("https://rezone-459910.oa.r.appspot.com/rest/execution/activity/log"),
                        headers: {'Authorization': 'Bearer ${widget.tokenID}', 'Content-Type': 'application/json'},
                        body: jsonEncode(body),
                      );

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(res.statusCode == 200 ? 'Atividade registada!' : 'Erro: ${res.body}'),
                      ));
                    },
                    child: const Text("Submeter")
                )
              ],
            ),
          ),
        ),
      ),
    );
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
                isPO
                    ? FloatingActionButton(
                      heroTag: 'tasksToggle',
                      backgroundColor: Colors.green,
                      onPressed: () async {
                        setState(() => isLoading = true);
                        await drawMyTaskPolygons();
                        setState(() => isLoading = false);
                      },
                      child: const Icon(Icons.assignment_turned_in, color: Colors.white),
                    )
                    : FloatingActionButton(
                      heroTag: 'activitiesToggle',
                      onPressed: toggleActivitiesMenu,
                      backgroundColor: Colors.green,
                      child: isActivitiesMenuOpen
                          ? const Icon(Icons.close, color: Colors.white)
                          : (selectedActivityIcon != null
                          ? SvgPicture.asset(selectedActivityIcon!, width: 24, height: 24, color: Colors.white)
                          : const Icon(Icons.menu, color: Colors.white)),
                    ),
                const SizedBox(height: 12),
                if (!isPO && isActivitiesMenuOpen) // TODO: add animation + make icon color match dark/light mode
                  Column(
                    children: [
                      _buildMenuButton(
                          svgIconPath: 'assets/icons/footprint.svg',
                          tag: 'jogging',
                          activityType: 'JOGGING',
                          onPressed: () async {
                            // TODO: Filter worksheets by all the worksheets and replace the map
                            // with the polygons of all the worksheets
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
                          tag: 'climbing',
                          activityType: 'CLIMBING',
                          onPressed: () async {
                            // TODO: Filter worksheets by the worksheets that not as recent
                            //  and replace the map with the polygons the worksheets
                            setState(() {
                              selectedActivityType = "CLIMBING";
                              selectedActivityIcon = 'assets/icons/hiking.svg';
                              isActivitiesMenuOpen = false;
                              isLoading = true;
                            });
                            await fetchPolygons(recent: false);
                            setState(() => isLoading = false);
                          }),
                      const SizedBox(height: 8),
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
                    ],
                  ),
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
          ),
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