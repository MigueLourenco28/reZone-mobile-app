import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  String? _tokenID, _fullName, _password;

  void _onLoginSuccess(String tokenID) {
    setState(() {
      _tokenID = tokenID;
      _isLoggedIn = true;
    });
  }

  void _onLogoutSuccess() {
    setState(() {
      _isLoggedIn = false;
      _tokenID = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green[700],
      ),
      home: _isLoggedIn
          ? HomeScreen(tokenID: _tokenID!, onLogoutSuccess: _onLogoutSuccess)
          : LoginRegisterScreen(onLoginSuccess: _onLoginSuccess),
    );
  }
}

class LoginRegisterScreen extends StatefulWidget {
  final void Function(String tokenID) onLoginSuccess;
  const LoginRegisterScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  bool isRegistering = true;
  bool isLoading = false;

  // Login
  final TextEditingController loginId = TextEditingController();
  final TextEditingController loginPassword = TextEditingController();

  // Register
  final TextEditingController regId = TextEditingController();
  final TextEditingController regEmail = TextEditingController();
  final TextEditingController regFullName = TextEditingController();
  final TextEditingController regPhone = TextEditingController();
  final TextEditingController regPassword = TextEditingController();
  final TextEditingController regConfirm = TextEditingController();
  String profileType = '';

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        widget.onLoginSuccess(tokenID);
      } else {
        showMessage("Login failed");
      }
    } catch (e) {
      showMessage("Error connecting to server.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> attemptRegister() async {
    final body = {
      "id": regId.text,
      "email": regEmail.text,
      "full_name": regFullName.text,
      "phone": regPhone.text,
      "profile": profileType,
      "password": regPassword.text,
      "confirmation": regConfirm.text,
    };
    if (body.values.any((v) => v.isEmpty)) {
      showMessage("All fields are required");
      return;
    }
    if (body["password"] != body["confirmation"]) {
      showMessage("Passwords don't match");
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
          onPressed: () => setState(() => isRegistering = true),
          child: Text("Register",
              style: TextStyle(
                  fontWeight: isRegistering ? FontWeight.bold : FontWeight.normal,
                  color: isRegistering ? Colors.green : Colors.grey)),
        ),
        Text("|"),
        TextButton(
          onPressed: () => setState(() => isRegistering = false),
          child: Text("Login",
              style: TextStyle(
                  fontWeight: !isRegistering ? FontWeight.bold : FontWeight.normal,
                  color: !isRegistering ? Colors.green : Colors.grey)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(
          mainAxisAlignment:MainAxisAlignment.center,
          children:[
            Text(
              'Welcome to ',
              style: TextStyle(
                fontFamily: 'Handler',
                fontSize: 45.0,
              ),
            ),
            Text(
              'Re',
              style: TextStyle(
                fontFamily: 'Handler',
                fontSize: 45.0,
                color: Colors.green,
              ),
            ),
            Text(
              'Zone ',
              style: TextStyle(
                fontFamily: 'Handler',
                fontSize: 45.0,
                color: Colors.blue,
              ),
            ),
            Image(
                image: AssetImage('assets/media/appLogo.png'),
                height: 45.0,
                width: 45.0
            ),
          ]
      )),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            toggleHeader(),
            const SizedBox(height: 16),
            isRegistering ? buildRegisterForm() : buildLoginForm(),
          ],
        ),
      ),
    );
  }

  Widget buildLoginForm() {
    return Column(
      children: [
        TextField(controller: loginId, decoration: const InputDecoration(labelText: 'User ID')),
        TextField(controller: loginPassword, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
        const SizedBox(height: 20),
        isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(onPressed: attemptLogin, child: const Text("Login")),
      ],
    );
  }

  Widget buildRegisterForm() {
    return Column(
      children: [
        TextField(controller: regId, decoration: const InputDecoration(labelText: 'User ID')),
        TextField(controller: regEmail, decoration: const InputDecoration(labelText: 'Email')),
        TextField(controller: regFullName, decoration: const InputDecoration(labelText: 'Full Name')),
        TextField(controller: regPhone, decoration: const InputDecoration(labelText: 'Phone Number')),
        DropdownButtonFormField<String>(
          value: profileType.isNotEmpty ? profileType : null,
          items: const [
            DropdownMenuItem(value: '', enabled: false, child: Text('Select a profile type')),
            DropdownMenuItem(value: 'public', child: Text('Public')),
            DropdownMenuItem(value: 'private', child: Text('Private')),
          ],
          onChanged: (value) => setState(() => profileType = value ?? ''),
          decoration: const InputDecoration(labelText: 'Profile Type'),
        ),
        TextField(controller: regPassword, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
        TextField(controller: regConfirm, decoration: const InputDecoration(labelText: 'Confirm Password'), obscureText: true),
        const SizedBox(height: 20),
        isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(onPressed: attemptRegister, child: const Text("Register")),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String tokenID;
  final VoidCallback onLogoutSuccess;
  const HomeScreen({super.key, required this.tokenID, required this.onLogoutSuccess});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 2;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const CommunityScreen(),
      const ActivitiesScreen(),
      const MapScreen(),
      ProfileScreen(
        tokenID: widget.tokenID,
        onLogoutSuccess: widget.onLogoutSuccess,
      ),
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
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
        unselectedLabelStyle: const TextStyle(
          //fontFamily: 'Handler',
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.landscape),
            label: 'Activities',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
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
    //TODO: Adicionar coordenadas extraídas do LanIt
    const LatLng _center = LatLng(39.5558, -8.0006); // Mação
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: _center, zoom: 11.0),
      onMapCreated: (_) {},
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final String tokenID;
  final VoidCallback onLogoutSuccess;

  const ProfileScreen({super.key, required this.tokenID, required this.onLogoutSuccess});

  Future<void> _updateProfileInformation(BuildContext context) async {
    //TODO
  }

  Future<void> _changePassword(BuildContext context) async {
    //TODO
  }

  Future<void> _logout(BuildContext context) async {
    //TODO: JWT Token
    onLogoutSuccess();
    final url = Uri.parse('https://apdc-2025-individual-66043.oa.r.appspot.com/rest/logout/');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"tokenID": tokenID}),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout error: $e')),
      );
    }
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
            child: Column(
              children: [
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