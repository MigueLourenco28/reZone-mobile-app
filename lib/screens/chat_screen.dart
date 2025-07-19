import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final String friendUsername;
  final String tokenID;
  const ChatScreen({super.key, required this.friendUsername, required this.tokenID});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  @override
  void initState() {
    super.initState();
    checkTokenExp();
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

  void _openGeminiChat() {
    print('Opening GeminiChatScreen - Button Pressed'); // Debug print
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeminiChatScreen(tokenID: widget.tokenID),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building ChatScreen'); // Debug print
    return Scaffold(
      appBar: AppBar(title: Text("Chat with ${widget.friendUsername}")),
      body: const SafeArea(
        child: Center(
          child: Text(
            "Still in development",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// GeminiChatScreen remains unchanged
class GeminiChatScreen extends StatefulWidget {
  final String tokenID;
  const GeminiChatScreen({super.key, required this.tokenID});

  @override
  State<GeminiChatScreen> createState() => _GeminiChatScreenState();
}

class _GeminiChatScreenState extends State<GeminiChatScreen> {
  List<Map<String, String>> messages = [];
  TextEditingController messageController = TextEditingController();
  bool isLoading = false;

  Future<void> sendGeminiMessage(String message) async {
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message cannot be empty.")),
      );
      return;
    }

    setState(() {
      messages.add({'sender': 'user', 'content': message});
      isLoading = true;
    });

    try {
      final res = await http.post(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/chat-gemini'),
        headers: {
          'Authorization': 'Bearer ${widget.tokenID}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': message}),
      );

      if (res.statusCode == 200) {
        final responseBody = jsonDecode(res.body);
        setState(() {
          messages.add({'sender': 'gemini', 'content': responseBody['message']});
          isLoading = false;
        });
        messageController.clear();
      } else if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unauthorized: Invalid or expired token.")),
        );
        setState(() => isLoading = false);
      } else {
        throw Exception('Failed to get Gemini response: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error communicating with Gemini: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chat with Rezone's AI")),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text("Start chatting with Rezone's AI!"))
                : ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: TextStyle(color: isUser ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(hintText: "Type a message to Rezone's AI..."),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => sendGeminiMessage(messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}