// screens/login_register_screen.dart
import '../utils/local_storage_util.dart';

import '../main.dart';
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

class LoginRegisterScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
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
    if (regUserName.text.isEmpty) {
      showMessage("Username is required");
      return;
    }
    if (regEmail.text.isEmpty) {
      showMessage("Email is required");
      return;
    }
    if (regPassword.text.isEmpty) {
      showMessage("Password is required");
      return;
    }
    if (regConfirm.text.isEmpty) {
      showMessage("Confirm password is required");
      return;
    }
    if (regPassword.text != regConfirm.text) {
      showMessage("Passwords do not match");
      return;
    }

    final body = {
      "userId": _generatedUserId,
      "username": regUserName.text,
      "email": regEmail.text,
      "password": regPassword.text,
      "confirmation": regConfirm.text,
      "fullName": regFullName.text,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  color: Theme.of(context).cardColor,
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
    String? hintText,
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
          hintText: hintText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
              Theme.of(context).canvasColor,
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
        _styledTextField(
          controller: loginId,
          label: 'User ID',
          hintText: 'Enter your user ID',
        ),
        _styledTextField(
          controller: loginPassword,
          label: 'Password',
          hintText: 'Enter your password',
          obscure: true,
        ),
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
          hintText: 'Auto-generated user ID',
          enabled: false,
        ),
        _styledTextField(
          controller: regUserName,
          label: 'Username',
          hintText: 'Enter your username',
        ),
        _styledTextField(
          controller: regEmail,
          label: 'Email',
          hintText: 'Enter your email',
        ),
        _styledTextField(
          controller: regPassword,
          label: 'Password',
          hintText: 'Enter your password',
          obscure: true,
        ),
        _styledTextField(
          controller: regConfirm,
          label: 'Confirm Password',
          hintText: 'Confirm your password',
          obscure: true,
        ),
        _styledTextField(
          controller: regFullName,
          label: 'Full Name',
          hintText: 'Enter your full name',
        ),
        _styledTextField(
          controller: regNationality,
          label: 'Nationality',
          hintText: 'Enter your nationality',
        ),
        _styledTextField(
          controller: regCountryOfRes,
          label: 'Country of Residence',
          hintText: 'Enter your country of residence',
        ),
        _styledTextField(
          controller: regAddress,
          label: 'Address',
          hintText: 'Enter your address',
        ),
        _styledTextField(
          controller: regPostalCode,
          label: 'Postal Code',
          hintText: 'Enter your postal code',
        ),
        _styledTextField(
          controller: regPrimaryPhone,
          label: 'Primary Phone',
          hintText: 'Enter your primary phone',
        ),
        _styledTextField(
          controller: regSecondaryPhone,
          label: 'Secondary Phone',
          hintText: 'Enter your secondary phone',
        ),
        _styledTextField(
          controller: regNIF,
          label: 'NIF',
          hintText: 'Enter your NIF',
        ),
        _styledTextField(
          controller: regCCNumber,
          label: 'CC Number',
          hintText: 'Enter your citizen card number',
        ),
        _styledTextField(
          controller: regCCIssueDate,
          label: 'CC Issue Date',
          hintText: 'Enter CC issue date',
        ),
        _styledTextField(
          controller: regCCIssuePlace,
          label: 'CC Issue Place',
          hintText: 'Enter CC issue place',
        ),
        _styledTextField(
          controller: regCCValidUntil,
          label: 'CC Valid Until',
          hintText: 'Enter CC valid until date',
        ),
        _styledTextField(
          controller: regBirthDate,
          label: 'Birth Date',
          hintText: 'Enter your birth date',
        ),
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