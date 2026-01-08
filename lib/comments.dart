import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter/material.dart';

class GameWithComments extends StatelessWidget {
  final String gameId;
  final Widget child;

  const GameWithComments({super.key, required this.gameId, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: child,
        ),
        const Divider(height: 1),
        SizedBox(
          height: 250,
          child: GameCommentSection(gameId: gameId),
        ),
      ],
    );
  }
}

class GameCommentSection extends StatefulWidget {
  final String gameId;

  const GameCommentSection({super.key, required this.gameId});

  @override
  State<GameCommentSection> createState() => _GameCommentSectionState();
}

class _GameCommentSectionState extends State<GameCommentSection> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  Future<void> _addMessage() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('guestbook').add({
          'text': _controller.text,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'name': user.displayName ?? 'Anonymous',
          'userId': user.uid,
          'game': widget.gameId,
        });
        _controller.clear();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('guestbook')
                .where('game', isEqualTo: widget.gameId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint(snapshot.error.toString());
                return const Center(child: Text('Something went wrong'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.requireData;

              return ListView.builder(
                reverse: true,
                itemCount: data.size,
                itemBuilder: (context, index) {
                  var message = data.docs[index];
                  final isCurrentUser =
                      FirebaseAuth.instance.currentUser?.uid == message['userId'];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(message['name']),
                    subtitle: Text(message['text']),
                    trailing: isCurrentUser
                        ? IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => message.reference.delete(),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Log in to chat'),
                  ),
                );
              }
              return Form(
                key: _formKey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Leave a comment',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your message to continue';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addMessage,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}