// other_page.dart
import 'package:flutter/material.dart';

class OtherPage extends StatefulWidget {
  final int lane;
  final int board;
  final double speed;
  final int shotNumber;

  const OtherPage({
    super.key,
    required this.lane,
    required this.board,
    required this.speed,
    required this.shotNumber,
  });

  @override
  State<OtherPage> createState() => _OtherPageState();
}

class _OtherPageState extends State<OtherPage> {
  late int lane;
  late int board;
  late double speed;

  final double _itemWidth = 40;

  @override
  void initState() {
    super.initState();
    lane = widget.lane;
    board = widget.board;
    speed = widget.speed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 1),
              Text(
                'Shot ${widget.shotNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              
              _buildHorizontalPicker(
                label: 'Lane',
                currentValue: lane,
                values: List.generate(10, (i) => i + 1),
                onChanged: (v) => setState(() => lane = v),
              ),
              _buildHorizontalPicker(
                label: 'Board',
                currentValue: board,
                values: List.generate(39, (i) => i + 1),
                onChanged: (v) => setState(() => board = v),
              ),
              _buildHorizontalPicker(
                label: 'Speed',
                currentValue: (speed * 10).round(),
                values: List.generate(351, (i) => (i + 50)), 
                onChanged: (v) => setState(() => speed = v / 10.0),
              ),
              const SizedBox(height: 2),
              Container(
                width: 80,
                height: 15,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(153, 153, 153, 1),
                  border: Border.all(color: Colors.black, width: 0.5),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    {'lane': lane, 'board': board, 'speed': speed},
                  ),
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
                      fontWeight: FontWeight.normal,
                      color: Colors.black
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalPicker({
    required String label,
    required int currentValue,
    required List<int> values,
    required ValueChanged<int> onChanged,
  }) {
    final controller = ScrollController(
      initialScrollOffset: (currentValue - values.first) * _itemWidth,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 1),

          LayoutBuilder(
            builder: (context, constraints) {
              final visibleWidth = constraints.maxWidth;

              void centerOnValue(int index) {
                final targetOffset =
                    (index * _itemWidth) - (visibleWidth / 2) + (_itemWidth / 2);
                controller.animateTo(
                  targetOffset.clamp(
                    controller.position.minScrollExtent,
                    controller.position.maxScrollExtent,
                  ),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                );
              }

              return Container(
                height: 20,
                width: 260,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF3A3A3A), 
                      Color(0xFF5B5B5B),
                      Color(0xFFDADADA), 
                      Color(0xFF5B5B5B),
                      Color(0xFF3A3A3A),
                    ],
                    stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.12, 0.88, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: values.length,
                      itemBuilder: (context, i) {
                        final isSelected = values[i] == currentValue;

                        return GestureDetector(
                          onTap: () {
                            onChanged(values[i]);
                            centerOnValue(i);
                          },
                          child: Container(
                            width: _itemWidth,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Colors.black.withOpacity(0.2),
                                  width: 0.8,
                                ),
                              ),
                            ),
                            child: Text(
                              label == 'Speed'
                                  ? (values[i] / 10.0).toStringAsFixed(1)
                                  : values[i].toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.black.withOpacity(0.4),
                                fontSize: isSelected ? 13 : 10,
                                fontWeight: isSelected
                                    ? FontWeight.normal
                                    : FontWeight.bold
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}