import 'dart:convert';
import 'dart:math';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
//TODO: guardar na base de dados local "util" o user id, token id e expiration date do token

void main() => runApp(const MyApp());

// Saves locally the four fields of the current user in use
class LocalStorageUtil {
  static Future<void> saveAuthData({
    required String tokenID,
    required String tokenExp,
    required String userRole,
    required String userID,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tokenID', tokenID);
    await prefs.setString('tokenExp', tokenExp);
    await prefs.setString('userRole', userRole);
    await prefs.setString('userID', userID);
  }

  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tokenID');
    await prefs.remove('tokenExp');
    await prefs.remove('userRole');
    await prefs.remove('userID');
  }

  static Future<Map<String, String?>> getAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'tokenID': prefs.getString('tokenID'),
      'tokenExp': prefs.getString('tokenExp'),
      'userRole': prefs.getString('userRole'),
      'userID': prefs.getString('userID'),
    };
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  bool _isCheckingLogin = true;

  void _onLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _onLogoutSuccess() async {
    await LocalStorageUtil.clearAuthData(); // Clear the data of the user using the app
    setState(() {
      _isLoggedIn = false;
    });
  }

  // Checks if the token of the user is still valid
  // Set the log in as true to skip the login screen
  Future<void> _checkStoredToken() async {
    final data = await LocalStorageUtil.getAuthData();
    final token = data['tokenID'];
    final exp = data['tokenExp'];

    if (token != null && exp != null) {
      try {
        bool isExpired = Jwt.isExpired(token);
        if (!isExpired) {
          setState(() {
            _isLoggedIn = true; // Directs user to HomeScreen
          });
        }
      } catch (e) {
        print("JWT validation failed: $e");
      }
    }

    setState(() {
      _isCheckingLogin = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkStoredToken();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green[700],
      ),
      home: _isCheckingLogin
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _isLoggedIn
            ? HomeScreen(onLogoutSuccess: _onLogoutSuccess)
            : LoginRegisterScreen(onLoginSuccess: _onLoginSuccess),
    );
  }
}

class LoginRegisterScreen extends StatefulWidget {
  final void Function() onLoginSuccess;
  const LoginRegisterScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  bool isRegistering = false;
  bool isLoading = false;
  late final int _generatedUserId;

  @override
  void initState() {
    super.initState();
    _generatedUserId = Random().nextInt(90000000) + 10000000; // TODO: check if it doesn't already exist
  }

  // Login
  final TextEditingController loginId = TextEditingController();
  final TextEditingController loginPassword = TextEditingController();

  // Register
  final TextEditingController regUserName = TextEditingController();
  final TextEditingController regEmail = TextEditingController();
  final TextEditingController regPassword = TextEditingController();
  final TextEditingController regConfirm = TextEditingController();
  final TextEditingController regFullName = TextEditingController();
  final TextEditingController regNationality = TextEditingController();
  final TextEditingController regCountryOfRes = TextEditingController();
  final TextEditingController regAddress = TextEditingController();
  final TextEditingController regPostalCode = TextEditingController();
  final TextEditingController regPrimaryPhone = TextEditingController();
  final TextEditingController regSecondaryPhone = TextEditingController();
  final TextEditingController regNIF = TextEditingController();
  final TextEditingController regCCNumber = TextEditingController();
  final TextEditingController regCCIssueDate = TextEditingController();
  final TextEditingController regCCIssuePlace = TextEditingController();
  final TextEditingController regCCValidUntil = TextEditingController();
  final TextEditingController regBirthDate = TextEditingController();

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Extract payload from jwt token and check if it is valid
  Map<String, dynamic> _parseJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid JWT');
    }
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final payloadMap = json.decode(utf8.decode(base64Url.decode(normalized)));

    if (payloadMap is! Map<String, dynamic>) {
      throw Exception('Invalid payload');
    }

    return payloadMap;
  }

  Future<void> attemptLogin() async {
    final body = {"id": loginId.text, "password": loginPassword.text};
    if (body.values.any((v) => v.isEmpty)) {
      showMessage("Fill in both fields");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        final responseJson = jsonDecode(res.body);
        final tokenID = responseJson['token'];
        final userRole = responseJson['role'];
        final userID = responseJson['username'];

        // Extract tokenExp from jwt token
        final payload = _parseJwtPayload(tokenID);
        final tokenExp = payload['exp'] as int;

        // Save to local storage
        await LocalStorageUtil.saveAuthData(
          tokenID: tokenID,
          tokenExp: tokenExp.toString(),
          userRole: userRole,
          userID: userID,
        );

        widget.onLoginSuccess();
      } else {
        showMessage("Login failed: ${res.body}");
      }
    } catch (e) {
      showMessage("Error connecting to server.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> attemptRegister() async {
    final body = {
      "userId": _generatedUserId,
      "username": regUserName.text,
      "email": regEmail.text,
      "password": regPassword.text,
      "confirmation": regConfirm.text,
      "full_name": regFullName.text,
      "nationality": regNationality.text,
      "residenceCountry": regCountryOfRes.text,
      "address": regAddress.text,
      "postalCode": regPostalCode.text,
      "phone1": regPrimaryPhone.text,
      "phone2": regSecondaryPhone.text,
      "nif": regNIF.text,
      "cc": regCCNumber.text,
      "ccIssueDate": regCCIssueDate.text,
      "ccIssuePlace": regCCIssuePlace.text,
      "ccValidUntil": regCCValidUntil.text,
      "birthDate": regBirthDate.text
    };
    if (body.entries.any((e) => e.value is String && (e.value as String).isEmpty)) {
      showMessage("All text fields are required");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        showMessage("Registration successful");
        setState(() => isRegistering = false); // go to login
      } else {
        showMessage("Register failed: ${res.body}");
      }
    } catch (e) {
      showMessage("Error connecting to server.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget toggleHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () => setState(() => isRegistering = false),
          child: Text("Login",
              style: TextStyle(
                  fontWeight: !isRegistering ? FontWeight.bold : FontWeight.normal,
                  color: !isRegistering ? Colors.green : Colors.grey)),
        ),
        Text("|"),
        TextButton(
          onPressed: () => setState(() => isRegistering = true),
          child: Text("Register",
              style: TextStyle(
                  fontWeight: isRegistering ? FontWeight.bold : FontWeight.normal,
                  color: isRegistering ? Colors.green : Colors.grey)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              toggleHeader(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: isRegistering ? buildRegisterForm() : buildLoginForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Welcome to ',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          'Re',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.green[700],
          ),
        ),
        Text(
          'Zone ',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.blue[700],
          ),
        ),
        const SizedBox(width: 8),
        const Image(
          image: AssetImage('assets/media/appLogo.png'),
          height: 32,
          width: 32,
        ),
      ],
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _styledTextField(controller: loginId, label: 'User ID'),
        _styledTextField(controller: loginPassword, label: 'Password', obscure: true),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              // TODO: Implement forgot password functionality
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Forgot Password"),
                  content: const Text("Feature not implemented yet."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            },
            child: const Text(
              "Forgot Password?",
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        isLoading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
          onPressed: attemptLogin,
          style: _buttonStyle(Colors.green),
          child: const Text("Login"),
        ),
      ],
    );
  }

  Widget buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _styledTextField(
          controller: TextEditingController(text: _generatedUserId.toString()),
          label: 'User ID',
          enabled: false,
        ),
        _styledTextField(controller: regUserName, label: 'Username'),
        _styledTextField(controller: regEmail, label: 'Email'),
        _styledTextField(controller: regPassword, label: 'Password', obscure: true),
        _styledTextField(controller: regConfirm, label: 'Confirm Password', obscure: true),
        _styledTextField(controller: regFullName, label: 'Full Name'),
        _styledTextField(controller: regNationality, label: 'Nationality'),
        _styledTextField(controller: regCountryOfRes, label: 'Country of Residence'),
        _styledTextField(controller: regAddress, label: 'Address'),
        _styledTextField(controller: regPostalCode, label: 'Postal Code'),
        _styledTextField(controller: regPrimaryPhone, label: 'Primary Phone'),
        _styledTextField(controller: regSecondaryPhone, label: 'Secondary Phone'),
        _styledTextField(controller: regNIF, label: 'NIF'),
        _styledTextField(controller: regCCNumber, label: 'CC Number'),
        _styledTextField(controller: regCCIssueDate, label: 'CC Issue Date'),
        _styledTextField(controller: regCCIssuePlace, label: 'CC Issue Place'),
        _styledTextField(controller: regCCValidUntil, label: 'CC Valid Until'),
        _styledTextField(controller: regBirthDate, label: 'Birth Date'),
        const SizedBox(height: 20),
        isLoading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
          onPressed: attemptRegister,
          style: _buttonStyle(Colors.blue),
          child: const Text("Register"),
        ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogoutSuccess;
  const HomeScreen({super.key, required this.onLogoutSuccess});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? tokenID, tokenExp, userRole, userID;
  List<Widget>? _pages;
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await LocalStorageUtil.getAuthData();
    setState(() {
      tokenID = data['tokenID'];
      tokenExp = data['tokenExp'];
      userRole = data['userRole'];
      userID = data['userID'];

      _pages = [
        const CommunityScreen(),
        const ActivitiesScreen(),
        const MapScreen(),
        ProfileScreen(
          tokenID: tokenID!,
          tokenExp: tokenExp!,
          userRole: userRole!,
          userID: userID!,
          onLogoutSuccess: widget.onLogoutSuccess,
        ),
        const SettingsScreen(),
      ];
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {

    if (_pages == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: _pages![_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(
          //fontFamily: 'Handler',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.landscape), label: 'Activities'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings')
        ],
      ),
    );
  }
}

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Community')),
      body: Center(child: Text('Community content goes here')),
    );
  }
}

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Activities')),
      body: Center(child: Text('Activity content goes here')),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    //TODO: Adicionar coordenadas extraídas do LandIt
    const LatLng _center = LatLng(39.5558, -8.0006); // Mação
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: _center, zoom: 13),
      onMapCreated: (_) {},
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final String tokenID, tokenExp, userRole, userID;
  final VoidCallback onLogoutSuccess;

  const ProfileScreen({super.key, required this.tokenID, required this.tokenExp,
    required this.userRole, required this.userID, required this.onLogoutSuccess});

  Future<void> _showProfileInformation(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/user/info'),
        headers: {
          'Authorization': 'Bearer $tokenID',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userData = jsonDecode(response.body);

        // Format user data into a readable string
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching profile: $e")),
      );
    }
  }

  Future<void> _updateProfileInformation(BuildContext context) async {
    //TODO
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
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("New passwords do not match.")),
                  );
                  return; // TODO: reset form and not exit
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
                      'Authorization': 'Bearer $tokenID', // Give token to allow the server to get the user ID
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

  Future<void> _changeProfileVisibility(BuildContext context) async {
    //TODO
  }

  Future<void> _logout(BuildContext context) async {
    //The Token is stored on the client, therefore there is no need to send it to the server
    onLogoutSuccess();
  }

  Future<void> _requestAccountRemoval(BuildContext context) async {
    //TODO
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(
          mainAxisAlignment:MainAxisAlignment.center,
          children: [
            Text(
              'Profile',
              style: TextStyle(
                fontFamily: 'Handler',
                fontSize: 45.0,
              ),
           ),
            Icon(
              Icons.person,
              size: 45.0,
            ),
          ]
      )),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            // TODO: List user info
            // (id, username, email, full name, nationality, country of residence,
            // address, postal code, primary phone, secondary phone, nif,
            // cc number, cc issue date, cc issue place, cc valid until,
            // birth date, role, account state, profile visibility)
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hello User: $userID',
                    style: TextStyle(
                      //position to the left
                      fontSize: 20.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => _showProfileInformation(context),
                  child: const Text('Profile Information'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => _updateProfileInformation(context),
                  child: const Text('Update Profile Information'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => _changePassword(context),
                  child: const Text('Change Password'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => _changeProfileVisibility(context),
                  child: const Text('Change Profile Visibility'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => _logout(context),
                  child: const Text('Log Out'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => _requestAccountRemoval(context),
                  child: const Text('Request Account Removal'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Center(child: Text('Setting content goes here')),
    );
  }
}