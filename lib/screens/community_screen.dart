import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat_screen.dart';

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
  int selectedTab = 0; // 0 = Friends, 1 = Chat
  String searchQuery = '';
  String currentUsername = '';

  @override
  void initState() {
    super.initState();
    final token = widget.tokenID;
    final parts = token.split('.');
    if (parts.length == 3) {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      currentUsername = payload['sub'];
    }
    fetchPublicUsers();
    fetchUserFriends();
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
                        .where((u) =>
                    u['username']!.toLowerCase().contains(searchQuery.toLowerCase()) &&
                        !isFriend(u['username']!))
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Community"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => setState(() => selectedTab = 0),
                child: Text(
                  "Friends",
                  style: TextStyle(
                    fontWeight: selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                    color: selectedTab == 0 ? Colors.green : Colors.grey,
                  ),
                ),
              ),
              const Text("|"),
              TextButton(
                onPressed: () => setState(() => selectedTab = 1),
                child: Text(
                  "Chat",
                  style: TextStyle(
                    fontWeight: selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                    color: selectedTab == 1 ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: selectedTab == 0
                ? userFriends.isEmpty
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
            )
                : userFriends.isEmpty
                ? const Center(child: Text("No friends to chat with"))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: userFriends.length,
              itemBuilder: (context, index) {
                final user = userFriends[index];
                if (user['username'] != null && user['username']!.isNotEmpty) {
                  print('Opening chat with friendUsername: ${user['username']}'); // Debug print
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              friendUsername: user['username']!.trim(), // Trim to avoid whitespace
                              tokenID: widget.tokenID,
                            ),
                          ),
                        );
                      },
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(user['username'] ?? 'Unnamed'),
                      trailing: const Icon(Icons.chat, size: 16),
                    ),
                  );
                } else {
                  return const SizedBox.shrink(); // Skip invalid users
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: selectedTab == 0
          ? FloatingActionButton(
        onPressed: showAddFriendPopup,
        backgroundColor: Colors.green,
        child: const Icon(Icons.person_add_alt_1, color: Colors.white),
      )
          : null,
    );
  }
}