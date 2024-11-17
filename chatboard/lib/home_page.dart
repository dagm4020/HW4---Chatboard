import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_drawer.dart';
import 'message_board_page.dart';
import 'login_page.dart';

class HomePage extends StatelessWidget {
  final List<MessageBoard> messageBoards = [
    MessageBoard(name: 'General Chat', imagePath: 'src/board1.png'),
    MessageBoard(name: 'Tech Talk', imagePath: 'src/board2.png'),
    MessageBoard(name: 'Gaming Hub', imagePath: 'src/board3.png'),
    MessageBoard(name: 'Sports', imagePath: 'src/board4.png'),
    MessageBoard(name: 'Foods', imagePath: 'src/board5.png'),
  ];

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chatboard Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LoginPage()),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: user == null
          ? Center(child: Text('No user is currently logged in.'))
          : Padding(
              padding: EdgeInsets.all(8.0),
              child: ListView.builder(
                itemCount: messageBoards.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    elevation: 5,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MessageBoardPage(
                              boardName: messageBoards[index].name,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 150,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15.0),
                                child: Image.asset(
                                  messageBoards[index].imagePath,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15.0),
                                  color: Colors.black.withOpacity(0.3),
                                ),
                              ),
                            ),
                            Center(
                              child: Text(
                                messageBoards[index].name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 6.0,
                                      color: Colors.black45,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class MessageBoard {
  final String name;
  final String imagePath;

  MessageBoard({required this.name, required this.imagePath});
}
