import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';

class MessageBoardPage extends StatefulWidget {
  final String boardName;

  MessageBoardPage({required this.boardName});

  @override
  _MessageBoardPageState createState() => _MessageBoardPageState();
}

class _MessageBoardPageState extends State<MessageBoardPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _currentUserFirstName = '';
  String _currentUserRole = '';

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
    _scheduleMidnightRefresh();
  }

  Future<void> _fetchCurrentUserDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _currentUserFirstName = userDoc['firstName'] ?? 'User';
          _currentUserRole = (userDoc['role'] ?? 'user').toLowerCase();
        });
      }
    }
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final difference = nextMidnight.difference(now);

    Timer(difference, () {
      setState(() {});
      _scheduleMidnightRefresh();
    });
  }

  Future<void> _sendMessage() async {
    String message = _messageController.text.trim();
    if (message.isEmpty) return;

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String senderFirstName = _currentUserFirstName;
      if (senderFirstName.isEmpty) {
        senderFirstName = 'User';
      }

      try {
        await FirebaseFirestore.instance
            .collection('message_boards')
            .doc(widget.boardName)
            .collection('messages')
            .add({
          'senderUid': user.uid,
          'senderFirstName': senderFirstName,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _messageController.clear();
        _scrollToBottom();
      } catch (e) {
        print('Error sending message: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message. Please try again.')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete All Messages'),
        content: Text(
            'Are you sure you want to delete all messages in this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAllMessages();
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllMessages() async {
    try {
      CollectionReference messagesRef = FirebaseFirestore.instance
          .collection('message_boards')
          .doc(widget.boardName)
          .collection('messages');

      QuerySnapshot allMessages = await messagesRef.get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in allMessages.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All messages have been deleted successfully.')),
      );
    } catch (e) {
      print('Error deleting messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete messages. Please try again.')),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('h:mm a').format(timestamp);
  }

  String getDateLabel(DateTime messageDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDay =
        DateTime(messageDate.year, messageDate.month, messageDate.day);

    if (messageDay == today) {
      return 'Today';
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEE, MMM d yyyy').format(messageDate);
    }
  }

  bool _shouldShowDateLabel(int index, List<QueryDocumentSnapshot> docs) {
    if (index >= docs.length) return false;

    if (index == 0) {
      return true;
    }

    final currentMessage = docs[index].data() as Map<String, dynamic>;
    final previousMessage = docs[index - 1].data() as Map<String, dynamic>;

    final currentTimestamp = currentMessage['timestamp'] as Timestamp?;
    final previousTimestamp = previousMessage['timestamp'] as Timestamp?;

    if (currentTimestamp == null || previousTimestamp == null) {
      return false;
    }

    final currentDate = currentTimestamp.toDate();
    final previousDate = previousTimestamp.toDate();

    final currentDay =
        DateTime(currentDate.year, currentDate.month, currentDate.day);
    final previousDay =
        DateTime(previousDate.year, previousDate.month, previousDate.day);

    return currentDay.isAfter(previousDay);
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _currentUserRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.boardName),
        actions: [
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _showDeleteConfirmationDialog,
              tooltip: 'Delete All Messages',
            ),
        ],
      ),
      drawer: AppDrawer(),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('message_boards')
                  .doc(widget.boardName)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return Center(child: Text('No messages found.'));
                }

                List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    bool showDateLabel = _shouldShowDateLabel(index, docs);

                    if (showDateLabel) {
                      final messageData =
                          docs[index].data() as Map<String, dynamic>;
                      final messageTimestamp =
                          messageData['timestamp'] as Timestamp?;
                      final messageDate =
                          messageTimestamp?.toDate() ?? DateTime.now();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Text(
                              getDateLabel(messageDate),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          _buildMessageBubble(docs[index], index, docs),
                        ],
                      );
                    } else {
                      return _buildMessageBubble(docs[index], index, docs);
                    }
                  },
                );
              },
            ),
          ),
          Divider(height: 1),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(25.0),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Enter your message',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 14.0),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.0),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(12.0),
                    child: Icon(
                      Icons.send,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      QueryDocumentSnapshot doc, int index, List<QueryDocumentSnapshot> docs) {
    final data = doc.data() as Map<String, dynamic>;
    final isMe = data['senderUid'] == FirebaseAuth.instance.currentUser?.uid;

    final timestamp = data['timestamp'] as Timestamp?;
    final messageDate = timestamp?.toDate();

    return Padding(
      padding: isMe
          ? EdgeInsets.only(left: 60.0, right: 12.0)
          : EdgeInsets.only(left: 12.0, right: 60.0),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              data['senderFirstName'] ?? 'User',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 6.0),
              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[200] : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.0),
                  topRight: Radius.circular(12.0),
                  bottomLeft: isMe ? Radius.circular(12.0) : Radius.circular(0),
                  bottomRight:
                      isMe ? Radius.circular(0) : Radius.circular(12.0),
                ),
              ),
              child: Text(
                data['message'] ?? '',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
            child: Text(
              messageDate != null
                  ? _formatTimestamp(messageDate)
                  : 'Sending...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
