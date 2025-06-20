import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

String tokenId = "";

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;

  void _onLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green[700],
      ),
      home: _isLoggedIn
          ? const HomeScreen()
          : LoginRegisterScreen(onLoginSuccess: _onLoginSuccess),
    );
  }
}

class LoginRegisterScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
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
        tokenId = responseJson['token'];
        widget.onLoginSuccess();
      } else {
        showMessage("Login failed");
      }
    } catch (e) {
      showMessage("Error: $e");
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
      showMessage("Error: $e");
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
              'Welcome to ReZone ',
              style: TextStyle(
                fontFamily: 'RobotoSlab',
                fontSize: 26.0,
              ),
            ),
            Image(
                image: AssetImage('assets/media/appLogo.png'),
                height: 30.0,
                width: 30.0),
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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;

  final List<Widget> _pages = const [
    CommunityScreen(),
    MapScreen(),
    ProfileScreen(),
  ];

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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
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

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const LatLng _center = LatLng(39.5558, -8.0006); // Mação
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: _center, zoom: 11.0),
      onMapCreated: (_) {},
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Center(child: Text('Profile information goes here')),
    );
  }
}