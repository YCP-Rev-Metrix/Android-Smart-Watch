// shot_page.dart
import 'package:flutter/material.dart';

class ShotPage extends StatefulWidget {
  // initialPins: List<bool> where true = pin is STANDING before this shot
  final List<bool> initialPins; 
  final int shotNumber;

  const ShotPage({super.key, required this.initialPins, required this.shotNumber});

  @override
  State<ShotPage> createState() => _ShotPageState();
}

class _ShotPageState extends State<ShotPage> {
  // true = pin is STANDING (i.e., not yet knocked down in this shot)
  late List<bool> currentPinsState; 
  String? selectedOutcome;
  bool isFoul = false;

  @override
  void initState() {
    super.initState();
    // Copy the initial pins standing (up) into the mutable state
    currentPinsState = List.from(widget.initialPins);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Shot ${widget.shotNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              _buildPinDisplay(),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildOutcomeBox("X"),
                  _buildOutcomeBox("/"),
                  _buildOutcomeBox("F"),
                  _buildSubmitButton(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePin(int index) {
    setState(() {
      // Toggle the state of the pin (standing <-> down), 
      // but ONLY if the pin was standing before this shot.
      if (widget.initialPins[index]) {
        currentPinsState[index] = !currentPinsState[index];
      }
    });
  }

  void _selectOutcome(String outcome) {
    setState(() {
      // Toggle selection
      selectedOutcome = selectedOutcome == outcome ? null : outcome;
      isFoul = false;

      // Auto-set pins based on standard outcomes
      if (selectedOutcome == "X") {
        // Strike: All pins standing initially are now DOWN (false)
        currentPinsState = List.filled(10, false);
      } else if (selectedOutcome == "/") {
        // Spare: All pins standing initially are now DOWN (false)
        currentPinsState = List.filled(10, false);
      } else if (selectedOutcome == "F") {
        // Foul: All pins standing initially are still STANDING (true)
        currentPinsState = List.from(widget.initialPins);
        isFoul = true;
      } else {
        // Reset to initial state if outcome is unselected or custom count is chosen
        currentPinsState = List.from(widget.initialPins);
      }
    });
  }

  void _submitShot(BuildContext context) {
    // 1. Determine final pins standing (true=standing)
    // Pins that were already down (false in initialPins) must remain down (false in currentPinsState).
    // The currentPinsState already handles this logic within _togglePin and _selectOutcome,
    // as it represents the pin state AFTER the shot relative to the initial state.
    
    final List<bool> pinsStanding = currentPinsState; 

    // 2. Calculate pins knocked down (Count)
    // Count = (Pins standing initially) - (Pins standing now)
    final int initialStandingCount = widget.initialPins.where((p) => p).length;
    final int currentStandingCount = pinsStanding.where((p) => p).length;
    final int pinsDownCount = initialStandingCount - currentStandingCount;
    
    Navigator.pop(context, {
      'pinsStanding': pinsStanding, // true = standing (for the leaveType bitmask)
      'pinsDownCount': pinsDownCount, // # of pins knocked down (Count)
      'outcome': selectedOutcome, // (Position)
      'isFoul': isFoul,
    });
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
            children: row.map((pin) => _buildPin(pin)).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPin(int pinNumber) {
    int index = pinNumber - 1;
    // Pin is UP (standing) if currentPinsState[index] is true
    bool isStanding = currentPinsState[index]; 
    // Pin is editable ONLY if it was standing initially
    bool isEditable = widget.initialPins[index];

    return GestureDetector(
      onTap: isEditable ? () => _togglePin(index) : null,
      child: Container(
        width: 31, 
        height: 31,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5), 
        decoration: BoxDecoration(
          // Color based on standing state (and initial state for visual context)
          color: isStanding
              ? const Color.fromRGBO(142, 124, 195, 1) // Standing (Up)
              : const Color.fromRGBO(153, 153, 153, 1), // Down
          shape: BoxShape.circle,
          border: Border.all(
            color: isEditable ? Colors.black : Colors.black.withOpacity(0.4), 
            width: 0.7,
          ),
        ),
      ),
    );
  }

  Widget _buildOutcomeBox(String symbol) {
    final bool isSelected = selectedOutcome == symbol;

    return GestureDetector(
      onTap: () {
        _selectOutcome(symbol);
        
        // Immediate submission for X, /, F. 
        // Delay to allow the setState in _selectOutcome to update the pins.
        if (symbol == "X" || symbol == "/" || symbol == "F") {
           WidgetsBinding.instance.addPostFrameCallback((_) => _submitShot(context));
        }
      },
      child: Container(
        width: 28,
        height: 25,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromRGBO(142, 124, 195, 1)
              : const Color.fromRGBO(153, 153, 153, 1),
          border: Border.all(color: Colors.black, width: 0.6),
        ),
        alignment: Alignment.center,
        child: Text(
          symbol,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return Container(
      width: 44,
      height: 25,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(153, 153, 153, 1),
        border: Border.all(color: Colors.black, width: 0.6),
      ),
      child: TextButton(
        onPressed: () => _submitShot(context),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.black,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
        child: const Text(
          'Submit',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}