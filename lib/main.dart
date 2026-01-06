import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:games_by_rohan/checkers_page.dart';
import 'package:games_by_rohan/chess_page.dart';
import 'package:games_by_rohan/connect4_page.dart';
import 'package:games_by_rohan/favorites_page.dart';
import 'package:games_by_rohan/generator_page.dart';
import 'package:games_by_rohan/go_page.dart';
import 'package:games_by_rohan/shogi_page.dart';
import 'package:games_by_rohan/game_2048_page.dart';
import 'package:provider/provider.dart';

void main() {
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
  var current = WordPair.random();
  var history = <WordPair>[];

  GlobalKey? historyListKey;

  void getNext() {
    history.insert(0, current);
    var animatedList = historyListKey?.currentState as AnimatedListState?;
    animatedList?.insertItem(0);
    current = WordPair.random();
    notifyListeners();
  }

  var favorites = <WordPair>[];

  void toggleFavorite([WordPair? pair]) {
    pair = pair ?? current;
    if (favorites.contains(pair)) {
      favorites.remove(pair);
    } else {
      favorites.add(pair);
    }
    notifyListeners();
  }

  void removeFavorite(WordPair pair) {
    favorites.remove(pair);
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  var _showRail = true;
  final GlobalKey _mainAreaKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;

    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
      case 1:
        page = FavoritesPage();
      case 2:
        page = ShogiPage();
      case 3:
        page = GoPage();
      case 4:
        page = ChessPage();
      case 5:
        page = CheckersPage();
      case 6:
        page = Connect4Page();
      case 7:
        page = Game2048Page();
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

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
                    items: [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.favorite),
                        label: 'Favorites',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.grid_on),
                        label: 'Shogi',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.circle_outlined),
                        label: 'Go',
                      ),
                      BottomNavigationBarItem(
                        icon: ImageIcon(AssetImage('assets/images/chess/Pawn.png')),
                        label: 'Chess',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.circle),
                        label: 'Checkers',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.grid_view),
                        label: 'Connect 4',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.door_sliding),
                        label: '2048',
                      ),
                    ],
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
                            destinations: [
                              NavigationRailDestination(
                                icon: Icon(Icons.home),
                                label: Text('Home'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.favorite),
                                label: Text('Favorites'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.grid_on),
                                label: Text('Shogi'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.circle_outlined),
                                label: Text('Go'),
                              ),
                              NavigationRailDestination(
                                icon: ImageIcon(AssetImage('assets/images/chess/Pawn.png')),
                                label: Text('Chess'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.circle),
                                label: Text('Checkers'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.grid_view),
                                label: Text('Connect 4'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.door_sliding),
                                label: Text('2048'),
                              ),
                            ],
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
