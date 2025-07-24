import '../utils/local_storage_util.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import 'package:url_launcher/url_launcher.dart';

class ActivitiesScreen extends StatefulWidget {
  final String tokenID;
  final VoidCallback onLogoutSuccess;
  const ActivitiesScreen({super.key, required this.tokenID, required this.onLogoutSuccess});

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
    checkTokenExp();
    decodeUsername();
    fetchUserActivities();
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

  void decodeUsername() {
    final parts = widget.tokenID.split('.');
    if (parts.length != 3) return;
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    currentUsername = payload['sub'];
  }

  Future<void> fetchUserActivities() async {
    try {
      final token = widget.tokenID;
      final parts = token.split('.');
      if (parts.length != 3) throw Exception('Invalid JWT format');
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      currentUsername = payload['sub'];

      final res = await http.get(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/activities/list'),
        headers: {'Authorization': 'Bearer $token'},
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

  String _formatForCalendar(DateTime dt) {
    final y = dt.toUtc().year.toString().padLeft(4, '0');
    final m = dt.toUtc().month.toString().padLeft(2, '0');
    final d = dt.toUtc().day.toString().padLeft(2, '0');
    final h = dt.toUtc().hour.toString().padLeft(2, '0');
    final min = dt.toUtc().minute.toString().padLeft(2, '0');
    final s = dt.toUtc().second.toString().padLeft(2, '0');
    return "$y$m$d" "T$h$min${s}Z";
  }

  void showActivityPopup(Map<String, String> activity) {
    final place = activity['activityPlace'] ?? '';
    final coords = place.split(',');

    final double? lat = coords.length == 2 ? double.tryParse(coords[0]) : null;
    final double? lng = coords.length == 2 ? double.tryParse(coords[1]) : null;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.green,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: getActivityIcon(activity['activityType'] ?? 'CAMPING', color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${activity['activityType']} with ${activity['friendUserName']}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              infoRow(Icons.calendar_today, "Date: ${activity['activityDate']}"),
              infoRow(Icons.access_time, "Time: ${activity['activityTime']}"),
              const SizedBox(height: 16),
              if (lat != null && lng != null)
                Column(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text("Open in Google Maps"),
                      onPressed: () async {
                        final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Could not launch Google Maps")),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.event),
                      label: const Text("Add to Calendar"),
                        onPressed: () async {
                          try {
                            final title = "${activity['activityType']} with ${activity['friendUserName']}";
                            final date = activity['activityDate'] ?? '';
                            final time = activity['activityTime'] ?? '';

                            print("DATA: $date, HORA: $time");

                            final dateParts = date.contains('-') ? date.split('-') : date.split('/');
                            final timeParts = time.split(':');

                            int? year, month, day;

                            if (date.contains('-')) {
                              // formato YYYY-MM-DD
                              year = int.tryParse(dateParts[0]);
                              month = int.tryParse(dateParts[1]);
                              day = int.tryParse(dateParts[2]);
                            } else {
                              // formato DD/MM/YYYY
                              day = int.tryParse(dateParts[0]);
                              month = int.tryParse(dateParts[1]);
                              year = int.tryParse(dateParts[2]);
                            }

                            final hour = int.tryParse(timeParts[0]);
                            final minute = int.tryParse(timeParts[1]);

                            if (year != null && month != null && day != null && hour != null && minute != null) {
                              final startDateTime = DateTime(year, month, day, hour, minute);
                              final endDateTime = startDateTime.add(const Duration(hours: 1));

                              final calendarUri = Uri.parse(
                                  "https://www.google.com/calendar/render?action=TEMPLATE"
                                      "&text=${Uri.encodeComponent(title)}"
                                      "&dates=${_formatForCalendar(startDateTime)}/${_formatForCalendar(endDateTime)}"
                                      "&details=${Uri.encodeComponent('Scheduled activity')}"
                                      "&location=${Uri.encodeComponent('$lat,$lng')}"
                                      "&sf=true&output=xml"
                              );

                              if (await canLaunchUrl(calendarUri)) {
                                await launchUrl(calendarUri, mode: LaunchMode.externalApplication);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Could not open calendar")),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Invalid date/time values")),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        }
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget getActivityIcon(String type, {Color color = Colors.green}) {
    switch (type.toUpperCase()) {
      case 'CAMPING':
        return SvgPicture.asset('assets/icons/camping.svg', color: color);
      case 'JOGGING':
        return SvgPicture.asset('assets/icons/footprint.svg', color: color);
      case 'CLIMBING':
        return SvgPicture.asset('assets/icons/hiking.svg', color: color);
      default:
        return Icon(Icons.nature, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
              leading: SizedBox(
                width: 36,
                height: 36,
                child: getActivityIcon(activity['activityType'] ?? '', color: Colors.green),
              ),
              title: Text("${activity['activityType']} with ${activity['friendUserName']}", style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: Text(activity['activityDate'] ?? ''),
            ),
          );
        },
      ),
    );
  }
}
