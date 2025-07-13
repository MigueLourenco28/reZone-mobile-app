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

class ActivitiesScreen extends StatefulWidget {
  final String tokenID;
  const ActivitiesScreen({super.key, required this.tokenID});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  List<Map<String, String>> userActivities = [];
  bool isLoading = true;
  String currentUsername = '';

  @override
  void initState() {
    super.initState();
    decodeToken();
    fetchActivities();
  }

  void decodeToken() {
    final payload = Jwt.parseJwt(widget.tokenID);
    currentUsername = payload['sub'];
  }

  Future<void> fetchActivities() async {
    try {
      final res = await http.get(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/activities/list'),
        headers: {'Authorization': 'Bearer ${widget.tokenID}'},
      );

      if (res.statusCode == 200) {
        final List<dynamic> activities = jsonDecode(res.body);
        setState(() {
          userActivities = activities.map<Map<String, String>>((a) => Map<String, String>.from(a)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed: ${res.body}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching activities: $e")),
      );
    }
  }

  IconData getIcon(String type) {
    switch (type.toUpperCase()) {
      case 'CAMPING': return Icons.park;
      case 'JOGGING': return Icons.directions_run;
      case 'CLIMBING': return Icons.terrain;
      default: return Icons.nature_people;
    }
  }

  void showActivityPopup(Map<String, String> activity) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(getIcon(activity['activityType'] ?? ''), size: 60, color: Colors.green),
              const SizedBox(height: 12),
              Text("${activity['activityType']} with ${activity['friendUserName']}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              infoRow(Icons.calendar_today, 'Date', activity['activityDate']),
              infoRow(Icons.access_time, 'Time', activity['activityTime']),
              infoRow(Icons.place, 'Place', activity['activityPlace']),
              const SizedBox(height: 20),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
            ],
          ),
        ),
      ),
    );
  }

  Widget infoRow(IconData icon, String label, String? value) {
    return Row(
      children: [Icon(icon), const SizedBox(width: 8), Text("$label: ${value ?? 'N/A'}")],
    );
  }

  void showAddActivityPopup() {
    final friendController = TextEditingController();
    final typeController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    final placeController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("New Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextField(controller: friendController, decoration: const InputDecoration(labelText: 'Friend Username')),
                TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Activity Type')),
                TextField(controller: dateController, decoration: const InputDecoration(labelText: 'Date (dd/MM/yyyy)')),
                TextField(controller: timeController, decoration: const InputDecoration(labelText: 'Time (HH:mm)')),
                TextField(controller: placeController, decoration: const InputDecoration(labelText: 'Place (lat, lng)')),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final newActivity = {
                      "username": currentUsername,
                      "friendUserName": friendController.text,
                      "activityType": typeController.text.toUpperCase(),
                      "activityDate": dateController.text,
                      "activityTime": timeController.text,
                      "activityPlace": placeController.text
                    };
                    final res = await http.post(
                      Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/activities/'),
                      headers: {
                        'Authorization': 'Bearer ${widget.tokenID}',
                        'Content-Type': 'application/json'
                      },
                      body: jsonEncode(newActivity),
                    );
                    if (res.statusCode == 200) {
                      Navigator.pop(context);
                      fetchActivities();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Activity added!")));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to add activity: ${res.body}")));
                    }
                  },
                  child: const Text("Create Activity"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Friend Activities", style: TextStyle(fontFamily: 'Handler', fontSize: 28)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userActivities.isEmpty
          ? const Center(child: Text("No activities yet"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: userActivities.length,
        itemBuilder: (context, index) {
          final activity = userActivities[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              onTap: () => showActivityPopup(activity),
              leading: Icon(getIcon(activity['activityType'] ?? ''), size: 36, color: Colors.green),
              title: Text("${activity['activityType']} with ${activity['friendUserName']}", style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(activity['activityDate'] ?? ''),
              trailing: const Icon(Icons.info_outline),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddActivityPopup,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}