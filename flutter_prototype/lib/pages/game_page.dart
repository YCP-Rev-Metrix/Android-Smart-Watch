// lib/pages/game_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'frame_page.dart'; 
import 'dev_settings_page.dart'; 
import '../controllers/session_controller.dart'; 

// Global access to the controller 
final SessionController _sessionController = SessionController(); 


// #############################################################
//                          1. GAME SHELL (The Main Page)
// #############################################################

class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  int _activeGame = 0;
  bool _gameSelectMode = false;

  final List<Color> gameColors = [
    Colors.grey.shade900,
    Colors.grey.shade800,
    Colors.grey.shade700,
    Colors.grey.shade600, 
    Colors.grey.shade500,
  ];

  @override
  void initState() {
    super.initState();
    _sessionController.addListener(_onSessionChange);
    _updateActiveGameSafety();
  }

  @override
  void dispose() {
    _sessionController.removeListener(_onSessionChange);
    super.dispose();
  }

  void _onSessionChange() {
    setState(() {
      _updateActiveGameSafety();
    });
  }

  void _updateActiveGameSafety() {
    final int gameCount = _sessionController.numOfGames;
    if (_activeGame >= gameCount) {
        _activeGame = gameCount - 1;
        if (_activeGame < 0) _activeGame = 0;
    }
  }

  void _enterGameSelection() {
    HapticFeedback.selectionClick();
    setState(() => _gameSelectMode = true);
  }

  void _exitGameSelection() {
    setState(() => _gameSelectMode = false);
  }

  void _selectGame(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _activeGame = index;
      _gameSelectMode = false;
      _sessionController.setActiveGame(_activeGame);
    });
  }

  @override
  Widget build(BuildContext context) {
    final int gameCount = _sessionController.numOfGames;
    
    _updateActiveGameSafety();

    return WillPopScope(
      onWillPop: () async => _gameSelectMode, 
      child: GestureDetector(
        onLongPress: _enterGameSelection, 
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BowlingGame(
              color: gameColors[_activeGame % gameColors.length], 
              index: _activeGame,
              gameCount: gameCount,
            ),
            
            if (_gameSelectMode)
              GameSelectionOverlay(
                activeGame: _activeGame,
                colors: gameColors,
                gameCount: gameCount, 
                onSelect: _selectGame,
                onCancel: _exitGameSelection,
              ),
          ],
        ),
      ),
    );
  }
}


// #############################################################
//                          2. BOWLING GAME (Adding Dynamic Controls)
// #############################################################

class BowlingGame extends StatefulWidget {
  final Color color;
  final int index;
  final int gameCount;
  const BowlingGame({
    super.key, 
    required this.color, 
    required this.index, 
    required this.gameCount,
  });

  @override
  State<BowlingGame> createState() => _BowlingGameState();
}

class _BowlingGameState extends State<BowlingGame> {
  
  void _onVerticalSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    // Swipe UP (negative velocity) Go to FrameShell (Score entry screen)
    if (details.primaryVelocity! < -200) {
      HapticFeedback.mediumImpact();
      Navigator.push( 
        context,
        MaterialPageRoute(builder: (_) => const FrameShell()),
      );
    }

    // Swipe DOWN (positive velocity) go back (pop to previous screen, e.g., Session Start)
    else if (details.primaryVelocity! > 200) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context); 
    }
  }

  void _addGame() {
    int currentCount = _sessionController.numOfGames;
    if (currentCount < 10) { 
      _sessionController.createNewSession(numOfGames: currentCount + 1);
    }
    HapticFeedback.lightImpact();
  }

  void _removeGame() {
    int currentCount = _sessionController.numOfGames;
    if (currentCount > 1) { 
      _sessionController.createNewSession(numOfGames: currentCount - 1);
    }
    HapticFeedback.lightImpact();
  }

  // Method to navigate to Dev Settings
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DevSettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {

    final Game? currentGame = (_sessionController.currentSession?.games.length ?? 0) > widget.index
        ? _sessionController.currentSession!.games[widget.index]
        : null;

    final String displayScore = currentGame?.totalScore.toString() ?? '---';
    final int currentCount = widget.gameCount; 
    
    return GestureDetector(
      onVerticalDragEnd: _onVerticalSwipe,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: widget.color,
        body: Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: const BoxDecoration(
              color: Color.fromRGBO(67, 67, 67, 1),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Game ${widget.index + 1} of $currentCount', 
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score: $displayScore',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: _removeGame,
                      tooltip: 'Remove Game',
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70),
                      onPressed: _openSettings,
                      tooltip: 'Dev Settings',
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                      onPressed: _addGame,
                      tooltip: 'Add Game',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// #############################################################
//                          3. GAME SELECTION OVERLAY (Remains Unchanged)
// #############################################################

class GameSelectionOverlay extends StatefulWidget {
  final int activeGame;
  final int gameCount; 
  final List<Color> colors; 
  final ValueChanged<int> onSelect;
  final VoidCallback onCancel;

  const GameSelectionOverlay({
    super.key,
    required this.activeGame,
    required this.colors,
    required this.gameCount, 
    required this.onSelect,
    required this.onCancel,
  });

  @override
  State<GameSelectionOverlay> createState() => _GameSelectionOverlayState();
}

class _GameSelectionOverlayState extends State<GameSelectionOverlay> {
  late final PageController _controller;
  late int _selected;
  bool _isSettling = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.activeGame;
    _controller = PageController(
      initialPage: _selected.clamp(0, widget.gameCount > 0 ? widget.gameCount - 1 : 0).toInt(), 
      viewportFraction: 0.8,
    );

    _controller.addListener(() {
      final page = _controller.page ?? _selected.toDouble();
      final diff = (page - page.round()).abs();
      final settling = diff > 0.001;
      if (settling != _isSettling) {
        setState(() => _isSettling = settling);
      }
    });
  }
  
  @override
  void didUpdateWidget(covariant GameSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gameCount != oldWidget.gameCount) {
      if (_selected >= widget.gameCount) {
        int newIndex = widget.gameCount - 1;
        if (newIndex < 0) newIndex = 0;
        _controller.jumpToPage(newIndex);
        _selected = newIndex;
      }
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  void _onPageChanged(int i) {
    setState(() => _selected = i);
    HapticFeedback.selectionClick();
  }

  void _onTapGame(int i) { 
    if (_isSettling) return;
    widget.onSelect(i);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.65; 

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: GestureDetector(
          onTap: widget.onCancel,
          behavior: HitTestBehavior.opaque,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.gameCount, 
            itemBuilder: (context, i) {
              final active = i == _selected;
              return Center(
                child: AnimatedScale(
                  scale: active ? 1.0 : 0.85,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    onTap: () => _onTapGame(i), 
                    child: Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        color: widget.colors[i % widget.colors.length], 
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Game ${i + 1}', 
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}