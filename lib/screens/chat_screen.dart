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
  List<Map<String, String>> messages = [];
  bool isLoading = true;
  String currentUsername = '';
  TextEditingController messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final token = widget.tokenID;
    final parts = token.split('.');
    if (parts.length == 3) {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      currentUsername = payload['sub'];
      print('Current username from JWT: $currentUsername'); // Debug print
    }
    print('Fetching messages with friendUsername: ${widget.friendUsername}'); // Debug print
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    try {
      final res = await http.get(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/chat/${widget.friendUsername}'),
        headers: {'Authorization': 'Bearer ${widget.tokenID}'},
      );
      if (res.statusCode == 200) {
        final List<dynamic> msgs = jsonDecode(res.body);
        setState(() {
          messages = msgs.map((m) => Map<String, String>.from(m)).toList();
          isLoading = false;
        });
      } else if (res.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You can only chat with your friends.")),
        );
        setState(() => isLoading = false);
      } else if (res.statusCode == 404) {
        final errorBody = jsonDecode(res.body);
        print('404 Error: ${errorBody['error']}'); // Log the exact error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${errorBody['error']}")),
        );
        setState(() => isLoading = false);
      } else {
        throw Exception('Failed to fetch messages: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching messages: $e")),
      );
    }
  }

  Future<void> sendMessage(String message) async {
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message cannot be empty.")),
      );
      return;
    }
    try {
      final res = await http.post(
        Uri.parse('https://rezone-459910.oa.r.appspot.com/rest/chat/${widget.friendUsername}'),
        headers: {
          'Authorization': 'Bearer ${widget.tokenID}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': message}),
      );
      if (res.statusCode == 200) {
        messageController.clear();
        await fetchMessages();
      } else if (res.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You can only chat with your friends.")),
        );
      } else {
        throw Exception('Failed to send message: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending message: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat with ${widget.friendUsername}")),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? const Center(child: Text("No messages yet. Start the conversation!"))
                : ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['sender'] == currentUsername;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.green : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: TextStyle(color: isMe ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(hintText: "Type a message..."),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => sendMessage(messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}