import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPage extends StatefulWidget {
  final String currentUserId;
  final String contactId;
  final String contactName;
  final String contactPhoneNumber; // Add the contact's phone number

  const ChatPage({
    Key? key,
    required this.currentUserId,
    required this.contactId,
    required this.contactName,
    required this.contactPhoneNumber, // Include the phone number
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();

  bool isContactValid = false;

  @override
  void initState() {
    super.initState();
    _checkContactExists();
  }

  // Check if the contact exists in both users' contact lists based on phone number
  Future<void> _checkContactExists() async {
    try {
      // Get the current user's data
      var currentUserSnapshot =
          await _firestore.collection('users').doc(widget.currentUserId).get();

      if (!currentUserSnapshot.exists) {
        setState(() {
          isContactValid = false;
        });
        return;
      }

      // Get the current user's contacts
      List<dynamic> currentUserContacts =
          currentUserSnapshot.data()!['contacts'] ?? [];

      // Check if the contact's phone number is in the current user's contact list
      bool isContactInCurrentUserContacts =
          currentUserContacts.contains(widget.contactPhoneNumber);

      // Get the contact's data
      var contactSnapshot =
          await _firestore.collection('users').doc(widget.contactId).get();

      if (!contactSnapshot.exists) {
        setState(() {
          isContactValid = false;
        });
        return;
      }

      // Get the contact's contacts list
      List<dynamic> contactUserContacts =
          contactSnapshot.data()!['contacts'] ?? [];

      // Check if the current user's phone number is in the contact's contact list
      bool isCurrentUserInContactUserContacts = contactUserContacts
          .contains(currentUserSnapshot.data()!['phoneNumber']);

      // If both users have saved each other's phone numbers, they can message
      if (isContactInCurrentUserContacts &&
          isCurrentUserInContactUserContacts) {
        setState(() {
          isContactValid = true;
        });
      } else {
        setState(() {
          isContactValid = false;
        });
      }
    } catch (e) {
      print("Error checking contact: $e");
      setState(() {
        isContactValid = false;
      });
    }
  }

  // Send a message
  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    String chatRoomId = getChatRoomId(widget.currentUserId, widget.contactId);

    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'senderId': widget.currentUserId,
      'recipientId': widget.contactId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  // Generate a unique chat room ID based on user IDs
  String getChatRoomId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode
        ? "$user1\_$user2"
        : "$user2\_$user1";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactName),
        backgroundColor: Colors.green,
      ),
      body: isContactValid
          ? Column(
              children: [
                // Messages Section
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('chats')
                        .doc(getChatRoomId(
                            widget.currentUserId, widget.contactId))
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

                      return ListView.builder(
                        reverse: true,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          Map<String, dynamic> data =
                              docs[index].data() as Map<String, dynamic>;

                          bool isMe = data['senderId'] == widget.currentUserId;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    isMe ? Colors.green[200] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(data['message']),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Message Input Section
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          _sendMessage(_messageController.text);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.block, color: Colors.red, size: 50),
                  SizedBox(height: 10),
                  Text(
                    'This contact is not available for messaging.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                ],
              ),
            ),
    );
  }
}
