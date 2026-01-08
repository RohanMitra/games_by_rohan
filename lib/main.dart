import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:games_by_rohan/checkers_page.dart';
import 'package:games_by_rohan/chess_page.dart';
import 'package:games_by_rohan/connect4_page.dart';
import 'package:games_by_rohan/generator_page.dart';
import 'package:games_by_rohan/go_page.dart';
import 'package:games_by_rohan/shogi_page.dart';
import 'package:games_by_rohan/game_2048_page.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Games by Rohan',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {

  String? username;
  List<String> allowedGames = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> login(String user) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: user)
          .get();

      if (snapshot.docs.isNotEmpty) {
        username = user;
        allowedGames = List<String>.from(snapshot.docs.first.data()['allowed_games'] ?? []);
      } else {
        errorMessage = 'User not found';
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    username = null;
    allowedGames = [];
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _PageItem {
  final String label;
  final Widget icon;
  final Widget page;
  final String? gameId;
  _PageItem(this.label, this.icon, this.page, [this.gameId]);
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  var _showRail = true;
  final GlobalKey _mainAreaKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    var appState = context.watch<MyAppState>();

    var allItems = [
      _PageItem('Home', Icon(Icons.home), GeneratorPage()),
      _PageItem('Shogi', Icon(Icons.grid_on), ShogiPage(), 'shogi'),
      _PageItem('Go', Icon(Icons.circle_outlined), GoPage(), 'go'),
      _PageItem('Chess', ImageIcon(AssetImage('assets/images/chess/Pawn.png')), ChessPage(), 'chess'),
      _PageItem('Checkers', Icon(Icons.circle), CheckersPage(), 'checkers'),
      _PageItem('Connect 4', Icon(Icons.grid_view), Connect4Page(), 'connect4'),
      _PageItem('2048', Icon(Icons.door_sliding), Game2048Page(), '2048'),
      _PageItem('Profile', Icon(Icons.account_circle), const LoginPage()),
    ];

    var visibleItems = allItems.where((item) {
      return item.gameId == null || (appState.username != null && appState.allowedGames.contains(item.gameId));
    }).toList();

    if (selectedIndex >= visibleItems.length) {
      selectedIndex = visibleItems.length - 1;
    }
    Widget page = visibleItems[selectedIndex].page;

    // The container for the current page, with its background color
    // and subtle switching animation.
    var mainArea = ColoredBox(
      key: _mainAreaKey,
      color: colorScheme.surfaceContainerHighest,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: page,
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            // Use a more mobile-friendly layout with BottomNavigationBar
            // on narrow screens.
            return Column(
              children: [
                Expanded(child: mainArea),
                SafeArea(
                  child: BottomNavigationBar(
                    selectedItemColor: Colors.blue,
                    unselectedItemColor: Colors.grey, 
                    items: visibleItems.map((item) => BottomNavigationBarItem(
                      icon: item.icon,
                      label: item.label,
                    )).toList(),
                    currentIndex: selectedIndex,
                    onTap: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                )
              ],
            );
          } else {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(Icons.menu),
                        onPressed: () {
                          setState(() {
                            _showRail = !_showRail;
                          });
                        },
                      ),
                      if (_showRail)
                        Expanded(
                          child: NavigationRail(
                            selectedIconTheme: IconThemeData(color: Colors.blue),
                            unselectedIconTheme: IconThemeData(color: Colors.grey),
                            extended: constraints.maxWidth >= 800,
                            destinations: visibleItems.map((item) => NavigationRailDestination(
                              icon: item.icon,
                              label: Text(item.label),
                            )).toList(),
                            selectedIndex: selectedIndex,
                            onDestinationSelected: (value) {
                              setState(() {
                                selectedIndex = value;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: mainArea),
              ],
            );
          }
        },
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final String? message;
  const LoginPage({super.key, this.message});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    Widget content;
    if (appState.username != null) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, ${appState.username}!',
              style: const TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            ElevatedButton(onPressed: appState.logout, child: Text('Logout')),
          ],
        ),
      );
    } else {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.message != null) Text(widget.message!),
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(height: 10),
              if (appState.isLoading)
                CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: () {
                    appState.login(_controller.text);
                  },
                  child: Text('Login'),
                ),
              if (appState.errorMessage != null)
                Text(appState.errorMessage!, style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background/Skybreakers.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        content,
      ],
    );  }
  }