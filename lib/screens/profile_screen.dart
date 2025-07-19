// screens/profile_screen.dart
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

class ProfileScreen extends StatefulWidget {
  final String tokenID, tokenExp, userRole, userID;
  final VoidCallback onLogoutSuccess;

  const ProfileScreen({
    super.key,
    required this.tokenID,
    required this.tokenExp,
    required this.userRole,
    required this.userID,
    required this.onLogoutSuccess,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isPrivate = false;

  @override
  void initState() {
    super.initState();
    checkTokenExp();
    fetchUserInfo();
  }

  void checkTokenExp() async {
    // Check if the token is still valid, if not, redirect to login page;
    final authData = await LocalStorageUtil.getAuthData();
    final tokenExp = authData['tokenExp'];

    if (tokenExp == null) {
      widget.onLogoutSuccess();
    }

    final expiration = int.tryParse(tokenExp);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now >= expiration) {
      widget.onLogoutSuccess();
    }
  }

  Future<void> fetchUserInfo() async {
    try {
      final res = await http.get(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/user/info'),
        headers: {'Authorization': 'Bearer ${widget.tokenID}'},
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> userData = jsonDecode(res.body);
        setState(() {
          isPrivate = userData['profile'] == "PRIVATE";
        });
      } else {
        throw Exception('Failed: ${res.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching user info: $e")),
      );
    }
  }

  Future<void> _showProfileInformation(BuildContext context) async {
    // Show loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/user/info'),
        headers: {
          'Authorization': 'Bearer ${widget.tokenID}',
        },
      );

      Navigator.of(context).pop(); // Remove loading dialog

      if (response.statusCode == 200) {
        final Map<String, dynamic> userData = jsonDecode(response.body);

        final infoText = userData.entries.map((e) => "${e.key}: ${e.value}").join('\n');

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Profile Information'),
            content: SingleChildScrollView(
              child: SelectableText(infoText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch profile: ${response.body}")),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Remove loading dialog if still shown
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching profile: $e")),
      );
    }
  }

  Future<void> _updateProfileInformation(BuildContext context) async {
    final controllers = {
      'Primary Phone': TextEditingController(),
      'Secondary Phone': TextEditingController(),
      'Address': TextEditingController(),
      'Postal Code': TextEditingController(),
      'Nationality': TextEditingController(),
      'Residence Country': TextEditingController(),
      'NIF': TextEditingController(),
      'Citizen Card': TextEditingController(),
      'CC Issue Date': TextEditingController(),
      'CC Issue Place': TextEditingController(),
      'CC Valid Until': TextEditingController(),
      'Birth Date': TextEditingController(),
      'Email': TextEditingController(),
      'Full Name': TextEditingController(),
    };

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Profile Information'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: controllers.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: entry.value,
                      obscureText: false,
                      decoration: InputDecoration(
                        labelText: entry.key,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final fieldMapping = {
                  'Primary Phone': 'new_phone1',
                  'Secondary Phone': 'new_phone2',
                  'Address': 'new_address',
                  'Postal Code': 'new_postal_code',
                  'Nationality': 'new_nationality',
                  'Residence Country': 'new_residence_country',
                  'NIF': 'new_nif',
                  'Citizen Card': 'new_cc',
                  'CC Issue Date': 'new_cc_issue_date',
                  'CC Issue Place': 'new_cc_issue_place',
                  'CC Valid Until': 'new_cc_valid_until',
                  'Birth Date': 'new_birth_date',
                  'Email': 'new_email',
                  'Full Name': 'new_full_name',
                };

                // Build body only with filled fields
                final Map<String, String> body = {"user": widget.userID};
                controllers.forEach((label, controller) {
                  if (controller.text.trim().isNotEmpty) {
                    final jsonKey = fieldMapping[label];
                    if (jsonKey != null) {
                      body[jsonKey] = controller.text.trim();
                    }
                  }
                });

                try {
                  final res = await http.post(
                    Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/change/attributes'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer ${widget.tokenID}',
                    },
                    body: jsonEncode(body),
                  );

                  Navigator.of(context).pop();

                  if (res.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Attributes changed successfully.")),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed: ${res.body}")),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
              ),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final current = currentPasswordController.text;
                final newPass = newPasswordController.text;
                final confirm = confirmPasswordController.text;

                if (newPass != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("New passwords do not match.")),
                  );
                  newPasswordController.clear();
                  confirmPasswordController.clear();
                  return;
                }

                final body = {
                  // Server should get user id from token
                  "oldPassword": current,
                  "newPassword": newPass,
                };

                try {

                  final res = await http.post(
                    Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/change/password'),
                    headers: {
                      'Content-Type': 'application/json', // TODO: get token from local data base
                      'Authorization': 'Bearer ${widget.tokenID}', // Give token to allow the server to get the user ID
                    },
                    body: jsonEncode(body),
                  );

                  Navigator.of(context).pop();

                  if (res.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Password changed successfully.")),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed: ${res.body}")),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeProfileVisibility(bool value) async {
    final newProfileValue = value ? "PRIVATE" : "PUBLIC";

    try {
      final res = await http.post(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/change/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.tokenID}',
        },
        body: jsonEncode({"profile": newProfileValue}),
      );

      if (res.statusCode == 200) {
        setState(() {
          isPrivate = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile changed to $newProfileValue')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change profile visibility: ${res.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    //The Token is stored on the client, therefore there is no need to send it to the server
    widget.onLogoutSuccess();
  }

  Future<void> _requestAccountRemoval(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Account Removal'),
          content: const Text(
            'Are you sure you want to request account removal?\nThis action may deactivate your account permanently.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    // If user cancels, exit early
    if (confirmed != true) return;

    try {
      final res = await http.post(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/remove/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.tokenID}',
        },
      );

      if (res.statusCode == 200) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent successfully.')),
        );
        widget.onLogoutSuccess();
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request account removal: ${res.body}')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Profile',
              style: TextStyle(
                fontFamily: 'Handler',
                fontSize: 36,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.person, size: 32),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${widget.userID}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text("Profile Privacy"),
                        subtitle: Text(
                          isPrivate ? "Your profile is PRIVATE" : "Your profile is PUBLIC",
                          style: const TextStyle(fontSize: 13),
                        ),
                        value: isPrivate,
                        onChanged: _changeProfileVisibility,
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Account Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Divider(thickness: 1.2),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => _showProfileInformation(context),
                icon: const Icon(Icons.info_outline),
                label: const Text('View Profile Information'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => _updateProfileInformation(context),
                icon: const Icon(Icons.edit),
                label: const Text('Update Profile Information'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => _changePassword(context),
                icon: const Icon(Icons.lock_reset),
                label: const Text('Change Password'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => _checkAccountStatus(),
                icon: const Icon(Icons.info_outline),
                label: const Text('Check Account Status'),
              ),
              _buildAdminSection(), // This line activates the admin section
              const SizedBox(height: 30),
              const Divider(thickness: 1.5),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => _requestAccountRemoval(context),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text(
                    'Request Account Removal',
                    style: TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Admin Section with all buttons, shown only if userRole is SYSADMIN or SYSBO

  Widget _buildAdminSection() {
    if (widget.userRole != 'SYSADMIN' && widget.userRole != 'SYSBO') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 30),
        const Text('Admin Operations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const Divider(thickness: 1.2),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: _changeUserRoleDialog,
          icon: const Icon(Icons.admin_panel_settings),
          label: const Text('Change User Role'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: () => _listUsers(),
          icon: const Icon(Icons.list_alt),
          label: const Text('List Users'),
        ),

        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: () => _toggleAccountState(),
          icon: const Icon(Icons.check_circle),
          label: const Text('Activate/Deactivate Account'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: () => _checkUserProfile(),
          icon: const Icon(Icons.person),
          label: const Text('Check Profile'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: () => _suspendUserDialog(),
          icon: const Icon(Icons.block),
          label: const Text('Suspend Account'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: () => _postSimpleAction('Remove User', '/rest/remove/confirm', 'user'),
          icon: const Icon(Icons.person_remove),
          label: const Text('Remove User Account'),
        ),
      ],
    );
  }

  Future<void> _changeUserRoleDialog() async {
    final usernameController = TextEditingController();
    String selectedRole = 'RU';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username')),
              DropdownButton<String>(
                value: selectedRole,
                items: ['SYSADMIN','SYSBO','SMBO','SGVBO','SDVBO','PRBO','ADLU','PO','RU','VU']
                    .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                    .toList(),
                onChanged: (val) => setState(() => selectedRole = val ?? 'RU'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final res = await http.post(
                  Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/change/changerole'),
                  headers: {
                    'Authorization': 'Bearer ${widget.tokenID}',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'user': usernameController.text.trim(),
                    'new_role': selectedRole
                  }),
                );
                Navigator.pop(context);
                final msg = res.statusCode == 200 ? 'Role changed successfully.' : 'Failed: ${res.body}';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              },
              child: const Text('Submit'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAccountState() async {
    final usernameController = TextEditingController();
    String selectedState = 'ACTIVE';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Toggle Account State'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              DropdownButton<String>(
                value: selectedState,
                items: ['ACTIVE', 'INACTIVE']
                    .map((state) => DropdownMenuItem(value: state, child: Text(state)))
                    .toList(),
                onChanged: (val) => setState(() => selectedState = val ?? 'ACTIVE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final username = usernameController.text.trim();
                if (username.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a username.')),
                  );
                  return;
                }

                try {
                  final res = await http.post(
                    Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/change/activate'),
                    headers: {
                      'Authorization': 'Bearer ${widget.tokenID}',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'username': usernameController.text.trim(),
                      'state': selectedState,
                    }),
                  );
                  Navigator.pop(context);
                  final msg = res.statusCode == 200
                      ? 'Account state changed to $selectedState.'
                      : 'Failed: ${res.body}';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _postSimpleAction(String title, String endpoint, String paramKey) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: paramKey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final res = await http.post(
                Uri.parse('https://rezone-459910.oa.r.appspot.com$endpoint'),
                headers: {
                  'Authorization': 'Bearer ${widget.tokenID}',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({paramKey: controller.text.trim()}),
              );
              Navigator.pop(context);
              final msg = res.statusCode == 200 ? 'Success' : 'Failed: ${res.body}';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            },
            child: const Text('Submit'),
          )
        ],
      ),
    );
  }

  Future<void> _suspendUserDialog() async {
    final usernameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Suspend User'),
        content: TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final res = await http.post(
                Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/change/suspend'),
                headers: {
                  'Authorization': 'Bearer ${widget.tokenID}',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'username': usernameController.text.trim(),
                  'state': 'SUSPENDED'
                }),
              );
              Navigator.pop(context);
              final msg = res.statusCode == 200 ? 'User suspended.' : 'Failed: ${res.body}';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            },
            child: const Text('Suspend'),


          )
        ],
      ),
    );
  }

  Future<void> _checkAccountStatus() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Check Account Status'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = controller.text.trim();
              if (username.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a username')),
                );
                return;
              }

              final uri = Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/change/checkstatus');
              final headers = {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${widget.tokenID}',
              };
              final body = jsonEncode({'username': username});

              Navigator.pop(context); // Close input dialog first

              try {
                final res = await http.post(uri, headers: headers, body: body);
                String msg;
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  msg = 'Username: ${data['username']}\n'
                      'Email: ${data['email']}\n'
                      'Account State: ${data['state']}';
                } else {
                  msg = 'Failed: ${res.body}';
                }

                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Account Status'),
                    content: SingleChildScrollView(child: SelectableText(msg)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Error'),
                    content: Text(e.toString()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Check'),
          )
        ],
      ),
    );
  }


  Future<void> _checkUserProfile() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Check Profile Visibility'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = controller.text.trim();
              if (username.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a username')),
                );
                return;
              }

              final uri = Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/change/checkprofile');
              final headers = {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${widget.tokenID}',
              };
              final body = jsonEncode({'username': username});

              Navigator.pop(context); // Close input dialog

              try {
                final res = await http.post(uri, headers: headers, body: body);
                String msg;
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  msg = 'Username: ${data['username']}\n'
                      'Email: ${data['email']}\n'
                      'Profile Visibility: ${data['profile']}';
                } else {
                  msg = 'Failed: ${res.body}';
                }

                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Profile Visibility'),
                    content: SingleChildScrollView(child: SelectableText(msg)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Error'),
                    content: Text(e.toString()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Check'),
          ),
        ],
      ),
    );
  }



  Future<void> _listUsers() async {
    String selectedRole = '';
    String selectedState = '';
    String selectedProfile = '';

    // Save the parent context to reuse later
    final parentContext = context;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              scrollable: true,
              title: const Text('All Registered Users'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: [
                      '',
                      'SYSADMIN', 'SYSBO', 'SMBO', 'SGVBO', 'SDVBO',
                      'PRBO', 'ADLU', 'PO', 'RU', 'VU'
                    ].map((role) => DropdownMenuItem(value: role, child: Text(role.isEmpty ? 'Any' : role))).toList(),
                    onChanged: (value) => setState(() => selectedRole = value ?? ''),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedState,
                    decoration: const InputDecoration(labelText: 'Account State'),
                    items: ['', 'ACTIVE', 'INACTIVE', 'SUSPENDED', 'A_REMOVER']
                        .map((state) => DropdownMenuItem(value: state, child: Text(state.isEmpty ? 'Any' : state)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedState = value ?? ''),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedProfile,
                    decoration: const InputDecoration(labelText: 'Profile'),
                    items: ['', 'PRIVATE', 'PUBLIC']
                        .map((profile) => DropdownMenuItem(value: profile, child: Text(profile.isEmpty ? 'Any' : profile)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedProfile = value ?? ''),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop(); // Close the filter dialog

                    final queryParams = <String, String>{};
                    if (selectedRole.isNotEmpty) queryParams['role'] = selectedRole;
                    if (selectedState.isNotEmpty) queryParams['state'] = selectedState;
                    if (selectedProfile.isNotEmpty) queryParams['profile'] = selectedProfile;

                    final uri = Uri.https(
                      'rezone-459910.oa.r.appspot.com',
                      '/rest/list/users',
                      queryParams,
                    );

                    final headers = {
                      'Authorization': 'Bearer ${widget.tokenID}',
                    };

                    try {
                      final res = await http.get(uri, headers: headers);

                      if (res.statusCode == 200) {
                        final data = jsonDecode(res.body);
                        final List users = data is List ? data : (data['users'] ?? []);

                        if (!parentContext.mounted) return;

                        showDialog(
                          context: parentContext,
                          builder: (_) => AlertDialog(
                            title: const Text('Users List'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: users.isEmpty
                                  ? const Text('No users found.')
                                  : ListView.builder(
                                shrinkWrap: true,
                                itemCount: users.length,
                                itemBuilder: (_, index) {
                                  final user = users[index];
                                  return ListTile(
                                    title: Text(user['username'] ?? ''),
                                    subtitle: Text('Email: ${user['email'] ?? 'N/A'}'),
                                  );
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(parentContext).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        final err = jsonDecode(res.body);
                        _showErrorDialog(parentContext, 'Failed: ${err['error'] ?? res.body}');
                      }
                    } catch (e) {
                      _showErrorDialog(parentContext, 'Error: $e');
                    }
                  },
                  child: const Text('Apply Filters'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

}