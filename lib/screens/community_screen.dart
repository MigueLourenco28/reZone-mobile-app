import '../utils/local_storage_util.dart';
import 'chat_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

class CommunityScreen extends StatefulWidget {
  final String tokenID;
  final VoidCallback onLogoutSuccess;
  const CommunityScreen({super.key, required this.tokenID, required this.onLogoutSuccess});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<Map<String, String>> publicUsers = [];
  List<Map<String, String>> userFriends = [];
  bool isLoading = true;
  String searchQuery = '';
  String currentUsername = '';

  @override
  void initState() {
    super.initState();
    checkTokenExp();
    final token = widget.tokenID;
    final parts = token.split('.');
    if (parts.length == 3) {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      currentUsername = payload['sub'];
    }
    fetchPublicUsers();
    fetchUserFriends();
  }

  void checkTokenExp() async {
    final authData = await LocalStorageUtil.getAuthData();
    final tokenExp = authData['tokenExp'];
    if (tokenExp == null) {
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

  Future<void> fetchUserFriends() async {
    try {
      final res = await http.get(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/user/friends'),
        headers: {'Authorization': 'Bearer ${widget.tokenID}'},
      );
      if (res.statusCode == 200) {
        final List<dynamic> friends = jsonDecode(res.body);
        setState(() {
          userFriends = friends.map((u) => Map<String, String>.from(u)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch friends: ${res.body}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching friends: $e")),
      );
    }
  }

  Future<void> fetchPublicUsers() async {
    try {
      final res = await http.get(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/list/public-users'),
        headers: {'Authorization': 'Bearer ${widget.tokenID}'},
      );
      if (res.statusCode == 200) {
        final List<dynamic> users = jsonDecode(res.body);
        setState(() {
          publicUsers = users
              .map<Map<String, String>>((u) => Map<String, String>.from(u))
              .where((user) =>
          user['username'] != currentUsername &&
              !userFriends.any((friend) => friend['username'] == user['username']))
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch public users: ${res.body}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching public users: $e")),
      );
    }
  }

  Future<void> addFriend(String friend) async {
    try {
      final res = await http.post(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/change/friends/add/$friend'),
        headers: {'Authorization': 'Bearer ${widget.tokenID}'},
      );
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Friend added successfully")),
        );
        setState(() {
          userFriends.add({'username': friend});
        });
        await fetchPublicUsers(); // Refresh public users to update the list
      } else {
        throw Exception('Failed to add friend: ${res.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding friend: $e")),
      );
    }
  }

  Future<void> removeFriend(String friend) async {
    try {
      final res = await http.post(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/change/friends/remove/$friend'),
        headers: {'Authorization': 'Bearer ${widget.tokenID}'},
      );
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Friend removed successfully")),
        );
        setState(() {
          userFriends.removeWhere((f) => f['username'] == friend);
        });
        await fetchPublicUsers(); // Refresh public users to update the list
      } else {
        throw Exception('Failed to remove friend: ${res.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error removing friend: $e")),
      );
    }
  }

  bool isFriend(String username) {
    return userFriends.any((friend) => friend['username'] == username);
  }

  void showUserPopup(Map<String, String> user) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.green,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                user['username'] ?? 'Unknown User',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (user['fullName'] != null)
                Row(
                  children: [
                    const Icon(Icons.badge),
                    const SizedBox(width: 8),
                    Expanded(child: Text("Full Name: ${user['fullName']}")),
                  ],
                ),
              if (user['email'] != null)
                Row(
                  children: [
                    const Icon(Icons.email),
                    const SizedBox(width: 8),
                    Expanded(child: Text("Email: ${user['email']}")),
                  ],
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                  isFriend(user['username']!)
                      ? ElevatedButton.icon(
                    onPressed: () {
                      removeFriend(user['username']!);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.person_remove),
                    label: const Text("Remove Friend"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  )
                      : ElevatedButton.icon(
                    onPressed: () {
                      addFriend(user['username']!);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text("Add Friend"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showAddFriendPopup() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Find New Friends", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(hintText: "Search username..."),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 300,
                  child: ListView(
                    children: publicUsers
                        .where((u) => u['username']!.toLowerCase().contains(searchQuery.toLowerCase()) && !isFriend(u['username']!))
                        .map((user) => ListTile(
                      onTap: () => showUserPopup(user),
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(user['username'] ?? ''),
                      trailing: ElevatedButton(
                        onPressed: () {
                          addFriend(user['username']!);
                          Navigator.pop(context);
                        },
                        child: const Text("Add"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openGeminiChat() {
    print('Opening GeminiChatScreen from CommunityScreen');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeminiChatScreen(tokenID: widget.tokenID),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building CommunityScreen with FloatingActionButtons');
    return Scaffold(
      appBar: AppBar(title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Community',
              style: TextStyle(
                fontFamily: 'Handler',
                fontSize: 45.0,
              ),
            ),
            Icon(
              Icons.groups,
              size: 45.0,
            ),
          ]
      )),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : userFriends.isEmpty
            ? const Center(child: Text("No friends yet"))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: userFriends.length,
          itemBuilder: (context, index) {
            final user = userFriends[index];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                onTap: () => showUserPopup(user),
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user['username'] ?? 'Unnamed'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
            );
          },
        ),
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: showAddFriendPopup,
              backgroundColor: Colors.green,
              mini: false,
              tooltip: 'Add Friend',
              child: const Icon(Icons.person_add_alt_1, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 50, // Adjusted to account for default padding
            child: FloatingActionButton(
              onPressed: _openGeminiChat,
              backgroundColor: Colors.green,
              mini: false,
              tooltip: "Rezone's AI Assistant",
              child: SvgPicture.asset(
                'assets/icons/gemini.svg',
                width: 28,
                height: 28,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}