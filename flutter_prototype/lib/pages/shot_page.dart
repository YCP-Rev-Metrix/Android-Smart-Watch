import 'package:flutter/material.dart';

class ShotPage extends StatefulWidget {
  final List<bool> initialPins;
  final int shotNumber;

  const ShotPage({super.key, required this.initialPins, required this.shotNumber});

  @override
  State<ShotPage> createState() => _ShotPageState();
}

class _ShotPageState extends State<ShotPage> {
  late List<bool> pins;
  String? selectedOutcome;

  @override
  void initState() {
    super.initState();
    pins = List.from(widget.initialPins);
  }

  void _togglePin(int index) {
    setState(() {
      pins[index] = !pins[index];
    });
  }

  void _selectOutcome(String outcome) {
    setState(() {
      selectedOutcome = selectedOutcome == outcome ? null : outcome;
    });
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Color.fromRGBO(67, 67, 67, 1),
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
  bool isDown = pins[index];

  return GestureDetector(
    onTap: () => _togglePin(index),
    child: Container(
      width: 31, 
      height: 31,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5), 
      decoration: BoxDecoration(
        color: isDown
            ? const Color.fromRGBO(153, 153, 153, 1)
            : const Color.fromRGBO(142, 124, 195, 1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 0.7),
      ),
    ),
  );
}




  Widget _buildOutcomeBox(String symbol) {
  final bool isSelected = selectedOutcome == symbol;

  return GestureDetector(
    onTap: () {
      _selectOutcome(symbol);

      setState(() {
        if (symbol == "X") {
          // Strike — all pins down
          pins = List.filled(10, true);
        } else if (symbol == "/") {
          // Spare — knock down all remaining standing pins
          for (int i = 0; i < pins.length; i++) {
            pins[i] = true;
          }
        } else if (symbol == "F") {
          // Foul — no pins hit
          pins = List.filled(10, false);
        }
      });
      Navigator.pop(context, {
  'pins': pins,
  'outcome': symbol,
  'lane': null,
  'board': null,
  'speed': null,
});
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
      onPressed: () {
        Navigator.pop(context, {
  'pins': pins,
  'outcome': selectedOutcome,
  'lane': null,
  'board': null,
  'speed': null,
});
      },
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