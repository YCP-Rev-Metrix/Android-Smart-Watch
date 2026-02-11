import 'package:flutter/material.dart';

class ShotInputPage extends StatefulWidget {
  final List<bool> initialPins;
  final int shotNumber;
  final int frameShotIndex;
  final int initialLane;
  final int initialBoard;
  final int initialBall;
  final double initialSpeed;
  final bool startInPost;
  final bool? initialIsFoul;

  const ShotInputPage({
    super.key,
    required this.initialPins,
    required this.shotNumber,
    required this.frameShotIndex,
    required this.initialLane,
    required this.initialBoard,
    required this.initialBall,
    required this.initialSpeed,
    required this.startInPost,
    this.initialIsFoul,
  });

  @override
  State<ShotInputPage> createState() => _ShotInputPageState();
}

class _ShotInputPageState extends State<ShotInputPage> {
  final PageController _pageController = PageController();
  late ScrollController _speedScrollController;
  int _currentPage = 0;
  int _selectedBall = 1;
  int _selectedBoard = 0;
  double _selectedSpeed = 15.0;
  late List<bool> _selectedPins;
  String? _selectedOutcome;
  bool _isRecording = false;
  double _selectedStance = 20.0;
  int _selectedLane = 1;

  // Demo data for recent results
  final List<String> _recentBoards = ['Right', 'Light Pocket', 'Pocket'];
  final List<int> _recentStances = [40, 25, 35];

  final List<String> _titles = [
    'Recent Results',
    'Select Ball',
    'Stance',
    'Record',
    'Shot',
    'Board',
    'Speed',
  ];

  final List<String> _boardOptions = [
    'Right',
    'Light',
    'Light pocket',
    'Pocket',
    'High pocket',
    'High',
    'Nose',
    'Brooklyn',
    'Left',
  ];

  final List<double> _speedOptions = List.generate(
    101,
    (index) => 10.0 + (index * 0.1),
  );

  @override
  void initState() {
    super.initState();
    _selectedPins = List.from(widget.initialPins);
    _speedScrollController = ScrollController();
    _speedScrollController.addListener(_onSpeedScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Scroll to the initial speed (15.0 is at index 50) after the view is built
      if (_speedScrollController.hasClients) {
        // Center the view so 15.0 is in the middle of the screen
        final itemCenterOffset = (50 * 50.0) + 25; // Center of the 50th item
        final screenCenterOffset = itemCenterOffset - (_speedScrollController.position.viewportDimension / 2);
        _speedScrollController.jumpTo(screenCenterOffset);
      }
    });
  }

  void _togglePin(int index) {
    setState(() {
      if (widget.initialPins[index]) {
        _selectedPins[index] = !_selectedPins[index];
      }
    });
  }

  void _selectOutcome(String outcome) {
    setState(() {
      _selectedOutcome = _selectedOutcome == outcome ? null : outcome;
      if (_selectedOutcome == 'X' || _selectedOutcome == '/') {
        _selectedPins = List.filled(10, false);
      } else if (_selectedOutcome == 'F' || _selectedOutcome == 'G') {
        _selectedPins = List.from(widget.initialPins);
      }
    });
  }

  void _onSpeedScroll() {
    // Calculate which item is in the center
    final centerOffset = _speedScrollController.offset + (_speedScrollController.position.viewportDimension / 2);
    final itemIndex = (centerOffset / 50.0).round().clamp(0, _speedOptions.length - 1);
    
    // Update selected speed
    setState(() {
      _selectedSpeed = _speedOptions[itemIndex];
    });
    
    // If scrolling stopped, snap to the item
    if (!_speedScrollController.position.isScrollingNotifier.value) {
      final itemCenterOffset = (itemIndex * 50.0) + 25;
      final targetOffset = itemCenterOffset - (_speedScrollController.position.viewportDimension / 2);
      _speedScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildPinDisplay() {
    List<List<int>> pinRows = [
      [7, 8, 9, 10],
      [4, 5, 6],
      [2, 3],
      [1],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: pinRows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((pin) => _buildPin(pin, size: 24.0)).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPin(int pinNumber, {double size = 24.0}) {
    int index = pinNumber - 1;
    bool isStanding = _selectedPins[index];
    bool isEditable = widget.initialPins[index];

    return GestureDetector(
      onTap: isEditable ? () => _togglePin(index) : null,
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.symmetric(horizontal: size * 0.04, vertical: size * 0.01),
        decoration: BoxDecoration(
          color: isStanding ? const Color.fromRGBO(142, 124, 195, 1) : const Color.fromRGBO(153, 153, 153, 1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isEditable ? Colors.black : Colors.black.withOpacity(0.4),
            width: 0.7,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          pinNumber.toString(),
          style: TextStyle(
            color: isStanding ? Colors.white : Colors.black87,
            fontSize: size * 0.36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOutcomeButton(String code, String label) {
    final isSelected = _selectedOutcome == code;
    final bgColor = isSelected ? const Color.fromRGBO(80, 200, 120, 1) : const Color.fromRGBO(153, 153, 153, 1);
    final textColor = isSelected ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: () => _selectOutcome(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: Colors.black, width: 0.6),
        ),
        child: Tooltip(
          message: label,
          child: Text(
            code,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _speedScrollController.removeListener(_onSpeedScroll);
    _speedScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _submit() {
    // Return the initial data as the shot result for now
    final pinsDownCount = widget.initialPins.where((p) => !p).length;
    Navigator.of(context).pop({
      'pinsStanding': widget.initialPins,
      'pinsDownCount': pinsDownCount,
      'outcome': pinsDownCount.toString(),
      'isFoul': widget.initialIsFoul ?? false,
      'lane': widget.initialLane,
      'board': _boardOptions[_selectedBoard],
      'speed': _selectedSpeed,
      'ball': _selectedBall,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: 7,
        itemBuilder: (context, index) {
          if (index == 1) {
            // Ball selector page
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 80,
                          child: ListWheelScrollView(
                            itemExtent: 20,
                            diameterRatio: 1.5,
                            onSelectedItemChanged: (index) {
                              setState(() {
                                _selectedBall = index + 1;
                              });
                            },
                            children: List.generate(4, (index) => Container(
                              color: index == _selectedBall - 1 ? Colors.white : Colors.transparent,
                              child: Center(
                                child: Text(
                                  'Ball ${index + 1}',
                                  style: TextStyle(
                                    color: index == _selectedBall - 1 ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Selected: Ball $_selectedBall',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else if (index == 2) {
            // Stance page with slider and lane dropdown
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: Text(
                    _titles[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Stance value display
                      Text(
                        _selectedStance.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Slider with 0 and 40 on sides
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  '0',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _selectedStance,
                                    min: 0,
                                    max: 40,
                                    divisions: 40,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedStance = value;
                                      });
                                    },
                                    activeColor: const Color.fromRGBO(142, 124, 195, 1),
                                    inactiveColor: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '40',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            // Center indicator line
                            Container(
                              height: 1,
                              color: Colors.grey[600],
                              margin: EdgeInsets.only(left: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Lane dropdown (horizontal layout)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Lane',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(100, 100, 100, 1),
                              border: Border.all(color: Colors.grey[700]!, width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButton<int>(
                              value: _selectedLane,
                              dropdownColor: const Color.fromRGBO(80, 80, 80, 1),
                              underline: const SizedBox(),
                              items: [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text(
                                    'Lane 1',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text(
                                    'Lane 2',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedLane = value ?? 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else if (index == 4) {
            // Shot screen with pins and outcome
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Pin Display
                        _buildPinDisplay(),
                        const SizedBox(height: 15),
                        // Outcome buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildOutcomeButton(widget.frameShotIndex == 0 ? 'X' : '/', widget.frameShotIndex == 0 ? 'Strike' : 'Spare'),
                            const SizedBox(width: 5),
                            _buildOutcomeButton('F', 'Foul'),
                            const SizedBox(width: 5),
                            _buildOutcomeButton('G', 'Gutter'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else if (index == 5) {
            // Board selector page
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 80,
                          child: ListWheelScrollView(
                            itemExtent: 20,
                            diameterRatio: 1.5,
                            onSelectedItemChanged: (index) {
                              setState(() {
                                _selectedBoard = index;
                              });
                            },
                            children: List.generate(_boardOptions.length, (index) => Container(
                              color: index == _selectedBoard ? Colors.white : Colors.transparent,
                              child: Center(
                                child: Text(
                                  _boardOptions[index],
                                  style: TextStyle(
                                    color: index == _selectedBoard ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Selected: ${_boardOptions[_selectedBoard]}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else if (index == 6) {
            // Speed selector page
            final speedIndex = _speedOptions.indexOf(_selectedSpeed);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            controller: _speedScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _speedOptions.length,
                            itemBuilder: (context, index) {
                              final speed = _speedOptions[index];
                              final isSelected = speed == _selectedSpeed;
                              return Container(
                                width: 50,
                                color: Colors.transparent,
                                child: Center(
                                  child: Text(
                                    speed.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.grey,
                                      fontSize: isSelected ? 14 : 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Selected: ${_selectedSpeed.toStringAsFixed(1)} mph',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(80, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: _submit,
                    child: const Text('Submit', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            );
          } else if (index == 3) {
            // Record page with record button
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isRecording = !_isRecording;
                          });
                        },
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: _isRecording ? Colors.redAccent : Colors.red,
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.fiber_manual_record,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isRecording ? 'Recording...' : 'Press to Record',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else if (index == 0) {
            // Recent Results page - info only
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 15, bottom: 10),
                  child: Text(
                    _titles[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Last 3 Boards
                          Text(
                            'Last 3 Boards',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._recentBoards.map((board) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              board,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          )),
                          const SizedBox(height: 10),
                          // Last 3 Stances
                          Text(
                            'Last 3 Stances',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._recentStances.map((stance) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              stance.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            );
          }
        },
      ),
    );
  }
}