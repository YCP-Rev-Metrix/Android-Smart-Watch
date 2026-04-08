// lib/pages/frame_page.dart


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_page.dart'; 
import 'shot_input_page.dart';
import '../controllers/session_controller.dart'; 
import '../models/shot.dart';

// Global access to the controller
final SessionController _sessionController = SessionController();




// #############################################################
// 						 1. FRAME SHELL
// #############################################################


class FrameShell extends StatefulWidget {
	const FrameShell({super.key});

	@override
	State<FrameShell> createState() => _FrameShellState();
}


class _FrameShellState extends State<FrameShell> {
	late int _viewFrameIndex;
	bool _frameSelectMode = false;
    // Flag to indicate if the user has manually selected a frame to view.
	bool _isManuallyViewingPastFrame = false; 


	final List<Color> frameColorPalette = const [
		Color.fromRGBO(67, 67, 67, 1),
		Color.fromRGBO(67, 67, 67, 1),
		Color.fromRGBO(67, 67, 67, 1),
	];
	
	int get _currentActiveFrameIndex => _sessionController.activeFrameIndex;


	@override
	void initState() {
		super.initState();
		_viewFrameIndex = _currentActiveFrameIndex;
	}

	void _onVerticalSwipe(DragEndDetails details) {
		if (details.primaryVelocity == null) return;


		if (details.primaryVelocity! > 200) {
			HapticFeedback.mediumImpact();
			Navigator.push(
				context,
				MaterialPageRoute(builder: (_) => const GameShell()),
			);
		}
	}


	void _enterFrameSelection() {
		HapticFeedback.selectionClick();
		setState(() => _frameSelectMode = true);
	}


	void _exitFrameSelection() {
		setState(() {
			_viewFrameIndex = _currentActiveFrameIndex; 
			_frameSelectMode = false;
            // Clear the flag when jumping back to the active input frame.
            _isManuallyViewingPastFrame = false;
		});
	}


	void _selectFrame(int index) {
		HapticFeedback.lightImpact();
		setState(() {
			_viewFrameIndex = index; 
			_frameSelectMode = false;
            // Set flag if a past frame was selected (i.e., not the current active frame).
			_isManuallyViewingPastFrame = (index != _currentActiveFrameIndex); 
		});
	}


	@override
	Widget build(BuildContext context) {
		return ListenableBuilder(
			listenable: _sessionController,
			builder: (context, child) {
				final inputFrameIndex = _currentActiveFrameIndex;

				final gameFrames = _sessionController.currentSession!.games[_sessionController.activeGameIndex].frames;
				final maxValidIndex = gameFrames.length - 1;


				// Ensure _viewFrameIndex is within bounds (0 to maxValidIndex)
				if (_viewFrameIndex < 0 || _viewFrameIndex > maxValidIndex) {
					_viewFrameIndex = inputFrameIndex.clamp(0, maxValidIndex).toInt();
				}

                if (!_isManuallyViewingPastFrame && _viewFrameIndex < inputFrameIndex) {
                    _viewFrameIndex = inputFrameIndex;
                }

				final shotsBeforeViewFrame = gameFrames
						.take(_viewFrameIndex)
						.fold(0, (sum, f) => sum + f.shots.length);
				
				final currentGlobalShotNumber = shotsBeforeViewFrame + (gameFrames[_viewFrameIndex].shots.length) + 1;
				
				return WillPopScope(
					onWillPop: () async => _frameSelectMode,
					child: GestureDetector(
						onLongPress: _enterFrameSelection,
						onVerticalDragEnd: _onVerticalSwipe,
						behavior: HitTestBehavior.translucent,
						child: Stack(
							fit: StackFit.expand,
							children: [
								BowlingFrame(
									frameIndex: _viewFrameIndex,
									color: frameColorPalette[_viewFrameIndex % frameColorPalette.length],
									shotNumber: currentGlobalShotNumber,
									isInputActive: _viewFrameIndex == inputFrameIndex,
								),
								if (_frameSelectMode)
									FrameSelectionOverlay(
										maxSelectableFrame: inputFrameIndex,
										activeFrame: _viewFrameIndex,
										colors: frameColorPalette,
										onSelect: _selectFrame,
										onCancel: _exitFrameSelection,
									),
							],
						),
					),
				);
			}
		);
	}
}

// #############################################################
// 						 2. BOWLING FRAME (Page View)
// #############################################################

class BowlingFrame extends StatefulWidget {
	final int frameIndex;
	final Color color;
	final int shotNumber; 
	final bool isInputActive;

	const BowlingFrame({
		super.key,
		required this.frameIndex,
		required this.color,
		required this.shotNumber,
		required this.isInputActive,
	});

	@override
	State<BowlingFrame> createState() => _BowlingFrameState();
}

class _BowlingFrameState extends State<BowlingFrame> {
	late PageController _controller;
	final _sessionController = SessionController();

	@override
	void initState() {
		super.initState();
		_initializeController();
	}

	// Helper to determine the correct starting page
	void _initializeController() {
		final frame = _sessionController.currentSession!.games[_sessionController.activeGameIndex].frames[widget.frameIndex];
		
		final initialPage = widget.isInputActive 
			? frame.shots.length 
			: (frame.shots.isNotEmpty ? frame.shots.length - 1 : 0);

		_controller = PageController(initialPage: initialPage.clamp(0, 2)); 
	}

	@override
	void didUpdateWidget(covariant BowlingFrame oldWidget) {
		super.didUpdateWidget(oldWidget);
		
		final newFrameIndex = widget.frameIndex;
		final oldFrameIndex = oldWidget.frameIndex;

		if (oldFrameIndex != newFrameIndex) {
			// Case 1: Frame changed (e.g., Strike or end of frame 9)
			_controller.dispose();
			_initializeController();
		} else if (widget.isInputActive) {
			// Case 2: Same frame, but a shot was recorded (or pins were cleared)
			final frame = _sessionController.currentSession!.games[_sessionController.activeGameIndex].frames[newFrameIndex];
			final newPage = frame.shots.length; // The index for the next shot is current shots.length
			final currentPage = _controller.page?.round() ?? 0;
			// If the new shot count is greater than the current visible page, animate to the new page.
			if (newPage > currentPage) {
				_controller.animateToPage(
					newPage,
					duration: const Duration(milliseconds: 300),
					curve: Curves.easeIn,
				);
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
		final activeGame = _sessionController.currentSession!.games[_sessionController.activeGameIndex];
		final frame = activeGame.frames[widget.frameIndex];

		final maxShotSlots = (widget.frameIndex == 9) ? 3 : 2;
		int itemCount;
		
		if (widget.isInputActive) {
			itemCount = (frame.shots.length + 1).clamp(1, maxShotSlots); 
		} else {
			itemCount = frame.shots.length;
			if (itemCount == 0) itemCount = 1;
		}

		final scrollPhysics = itemCount > 1 
			? const BouncingScrollPhysics() 
			: const NeverScrollableScrollPhysics();


		return Stack(
			children: [
				PageView.builder(
					controller: _controller,
					physics: scrollPhysics,
					itemCount: itemCount,
					itemBuilder: (context, pageIndex) { 
						
						final shotIndex = pageIndex;
						
						// Calculate the starting global shot number for this PageView
						final shotsBeforeFrame = activeGame.frames
							.take(widget.frameIndex)
							.fold(0, (sum, f) => sum + f.shots.length);
						final initialGlobalShot = shotsBeforeFrame + 1;
						
						final bool isCurrentInput = widget.isInputActive && (pageIndex == frame.shots.length);
						
						if (!widget.isInputActive && pageIndex >= frame.shots.length) {
							return Container(color: widget.color);
						}
						
						return BowlingShot(
							key: ValueKey('${widget.frameIndex}-${shotIndex + 1}'),
							color: widget.color,
							frameIndex: widget.frameIndex,
							shotIndex: shotIndex + 1,
							globalShotNumber: initialGlobalShot + shotIndex,
							isInputActive: isCurrentInput,
						);
					},
				),
			],
		);
	}
}


// #############################################################
// 						 3. FRAME SELECTION OVERLAY
// #############################################################


class FrameSelectionOverlay extends StatefulWidget {
	final int activeFrame;
	final int maxSelectableFrame;
	final List<Color> colors;
	final ValueChanged<int> onSelect;
	final VoidCallback onCancel;


	const FrameSelectionOverlay({
		super.key,
		required this.activeFrame,
		required this.maxSelectableFrame,
		required this.colors,
		required this.onSelect,
		required this.onCancel,
	});


	@override
	State<FrameSelectionOverlay> createState() => _FrameSelectionOverlayState();
}


class _FrameSelectionOverlayState extends State<FrameSelectionOverlay> {
	late final PageController _controller;
	late int _selected;
	bool _isSettling = false;


	@override
	void initState() {
		super.initState();
		_selected = widget.activeFrame;
		_controller = PageController(
			initialPage: _selected,
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
	void dispose() {
		_controller.dispose();
		super.dispose();
	}


	void _onPageChanged(int i) {
		setState(() => _selected = i);
		HapticFeedback.selectionClick();
	}


	void _onTapFrame(int i) {
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
						//Restrict the number of pages displayed (up to the current active frame)
						itemCount: widget.maxSelectableFrame + 1,
						itemBuilder: (context, i) {
							final active = i == _selected;
							
							final isComplete = _sessionController.currentSession!.games[_sessionController.activeGameIndex].frames[i].isComplete;
							
							final int colorIndex = i % widget.colors.length;
							
							final Color frameColor = isComplete
								? widget.colors[colorIndex]
								: widget.colors[colorIndex].withOpacity(0.5);
							
							return Center(
								child: AnimatedScale(
									scale: active ? 1.0 : 0.85,
									duration: const Duration(milliseconds: 150),
									curve: Curves.easeOutCubic,
									child: GestureDetector(
										onTap: () => _onTapFrame(i),
										child: Container(
											width: circleSize,
											height: circleSize,
											decoration: BoxDecoration(
												color: frameColor,
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
												'Frame ${i + 1}',
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


// #############################################################
// 						 4. BOWLING SHOT (Data Display)
// #############################################################


class BowlingShot extends StatefulWidget {
	final int frameIndex;
	final int shotIndex; 
	final int globalShotNumber;
	final Color color;
	final bool isInputActive;


	const BowlingShot({
		super.key,
		required this.frameIndex,
		required this.shotIndex,
		required this.globalShotNumber,
		required this.color,
		required this.isInputActive,
	});


	@override
	State<BowlingShot> createState() => _BowlingShotState();
}


class _BowlingShotState extends State<BowlingShot> {
	int lane = 1;
	double board = 17.0;
	double speed = 15.0;
	int ball = 1;
	double stance = 20.0;
	double target = 20.0;
	double breakPoint = 20.0;
	bool _showEmptyInfoBarValues = false;
	List<bool> pinsDown = List.filled(10, false);
	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		_updateShotDisplay();
	}
	@override
	void didUpdateWidget(covariant BowlingShot oldWidget) {
		super.didUpdateWidget(oldWidget);
		// Re-read the data if the frame/shot context changes
		if (oldWidget.frameIndex != widget.frameIndex || oldWidget.shotIndex != widget.shotIndex) {
			_updateShotDisplay();
		}
	}


	// Reads the current/previous shot data from the controller models
	void _updateShotDisplay() {
		final activeGame = _sessionController.currentSession!.games[_sessionController.activeGameIndex];
		final frame = activeGame.frames[widget.frameIndex];
		final previousMatchingShot = _findPreviousSameLaneShot(activeGame, frame.lane, widget.shotIndex);
	
		// Determine which shot data to display (if any)
		final shotToDisplay = frame.shots.length >= widget.shotIndex
					? frame.shots[widget.shotIndex - 1] 
					: null;
			
		setState(() {
			if (shotToDisplay != null) {
				_showEmptyInfoBarValues = false;
				pinsDown = shotToDisplay.pinsState.map((isStanding) => !isStanding).toList();
				lane = frame.lane;
				board = shotToDisplay.impact;
				speed = shotToDisplay.speed;
				ball = shotToDisplay.ball;
				stance = shotToDisplay.stance;
				target = shotToDisplay.target;
				breakPoint = shotToDisplay.breakPoint;
			} else {
			// Shot hasn't been submitted yet.
			if (previousMatchingShot != null) {
				pinsDown = previousMatchingShot.pinsState.map((isStanding) => !isStanding).toList();
				lane = previousMatchingShot.lane;
				board = previousMatchingShot.impact;
				speed = previousMatchingShot.speed;
				ball = previousMatchingShot.ball;
				stance = previousMatchingShot.stance;
				target = previousMatchingShot.target;
				breakPoint = previousMatchingShot.breakPoint;
				_showEmptyInfoBarValues = false;
			} else {
				// Use controller-level defaults when this frame has no prior shots
				pinsDown = List.filled(10, true);
				// Auto-flip lane every frame: frame 1 = lane 1, frame 2 = lane 2, etc.
				lane = (widget.frameIndex % 2 == 0) ? 1 : 2;
				board = _sessionController.defaultBoard;
				speed = _sessionController.defaultSpeed;
				ball = _sessionController.defaultBall;
				stance = _sessionController.defaultStanceByLane[lane] ?? 20.0;
				target = _sessionController.defaultTargetByLane[lane] ?? 20.0;
				breakPoint = _sessionController.defaultBreakPointByLane[lane] ?? 20.0;
				_showEmptyInfoBarValues = true;
			}
			}
		});
	}

	Shot? _findPreviousSameLaneShot(dynamic activeGame, int lane, int shotIndex) {
		for (int frameIdx = widget.frameIndex - 1; frameIdx >= 0; frameIdx--) {
			final candidateFrame = activeGame.frames[frameIdx];
			if (candidateFrame.lane == lane && candidateFrame.shots.length >= shotIndex) {
				return candidateFrame.shots[shotIndex - 1];
			}
		}
		return null;
	}

	void _openShotPage() async {
		final activeGame = _sessionController.currentSession!.games[_sessionController.activeGameIndex];
		final frame = activeGame.frames[widget.frameIndex];
		
		// Don't open if this is a read-only shot
		final shotToDisplay = frame.shots.length >= widget.shotIndex
			? frame.shots[widget.shotIndex - 1]
			: null;
		
		if (shotToDisplay != null && shotToDisplay.isReadOnly) {
			return; // Can't edit read-only shots
		}

		// Logic to set initial pins based on whether it's shot 1 or a subsequent shot,
		final initialPinsStanding = shotToDisplay != null
			? shotToDisplay.pinsState
			: (widget.shotIndex == 1 ? List.filled(10, true) : activeGame.frames[widget.frameIndex].shots.last.pinsState);

		final List<Shot> matchingPriorShots = [];
		for (int frameIdx = 0; frameIdx < activeGame.frames.length; frameIdx++) {
			final frame = activeGame.frames[frameIdx];
			for (int shotIdx = 0; shotIdx < frame.shots.length; shotIdx++) {
				final shotIndexInFrame = shotIdx + 1;
				final isBeforeCurrentPosition =
						frameIdx < widget.frameIndex ||
						(frameIdx == widget.frameIndex && shotIndexInFrame < widget.shotIndex);

				if (isBeforeCurrentPosition) {
					matchingPriorShots.add(frame.shots[shotIdx]);
				}
			}
		}

		final recentShots = matchingPriorShots.length <= 3
				? matchingPriorShots
				: matchingPriorShots.sublist(matchingPriorShots.length - 3);

		final balls = _sessionController.activeBalls;

		final shotResult = await Navigator.push<Map<String, dynamic>>(
			context,
			MaterialPageRoute(
				builder: (_) => ShotInputPage(
					initialPins: initialPinsStanding,
					recentShots: recentShots,
					shotNumber: widget.globalShotNumber,
					frameShotIndex: widget.shotIndex,
					frameNumber: widget.frameIndex + 1,
					initialLane: lane,
					initialImpact: board,
					initialBall: ball,
					initialSpeed: speed,
					initialStance: stance,
					initialTarget: target,
					initialBreakPoint: breakPoint,
					startInPost: shotToDisplay != null,
					initialIsFoul: shotToDisplay?.isFoul,
					balls: balls.isEmpty ? null : balls,
				),
			),
		);


		if (shotResult != null) {
			// Update the info bar values with selections returned from the shot page
			setState(() {
				lane = (shotResult['lane'] as int?) ?? lane;
				board = (shotResult['impact'] as num?)?.toDouble() ?? board;
				speed = (shotResult['speed'] as double?) ?? speed;
				ball = (shotResult['ball'] as int?) ?? ball;
				stance = (shotResult['stance'] as num?)?.toDouble() ?? stance;
				target = (shotResult['target'] as num?)?.toDouble() ?? target;
				breakPoint = (shotResult['breakPoint'] as num?)?.toDouble() ?? breakPoint;
			});

			if (shotToDisplay != null) {
				// Edit existing shot
				_sessionController.editShot(
					frameIndex: widget.frameIndex,
					shotIndexInFrame: widget.shotIndex - 1,
					lane: lane,
					speed: speed,
					impact: board,
					ball: ball,
					stance: stance,
					target: target,
					breakPoint: breakPoint,
					standingPins: shotResult['pinsStanding'] as List<bool>,
					pinsDownCount: shotResult['pinsDownCount'] as int,
					isFoul: shotResult['isFoul'] as bool,
				);
			} else {
				_recordShot(shotResult);
			}
		}
	}

	
	
	void _recordShot(Map<String, dynamic> shotResult) {
		final List<bool> pinsStandingResult = shotResult['pinsStanding'] as List<bool>;
		final int pinsDownCount = shotResult['pinsDownCount'] as int;
		final bool isFoul = shotResult['isFoul'] as bool;
		final int selectedBall = shotResult['ball'] as int? ?? ball;
		final double selectedStance = (shotResult['stance'] as num?)?.toDouble() ?? stance;
	
		_sessionController.recordShot(
			lane: lane,
			speed: speed,
			impact: board,
			ball: selectedBall,
			stance: selectedStance,
			target: target,
			breakPoint: breakPoint,
			standingPins: pinsStandingResult,
			pinsDownCount: pinsDownCount,
			isFoul: isFoul,
		);
	}


	Widget _buildPinDisplay(List<bool> pinsDownList) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				Row(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [7, 8, 9, 10].map((p) => _buildPin(p, pinsDownList, widget.shotIndex)).toList(),
				),
				const SizedBox(height: 3),
				Row(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [4, 5, 6].map((p) => _buildPin(p, pinsDownList, widget.shotIndex)).toList(),
				),
				const SizedBox(height: 3),
				Row(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [2, 3].map((p) => _buildPin(p, pinsDownList, widget.shotIndex)).toList(),
				),
				const SizedBox(height: 3),
				Row(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [_buildPin(1, pinsDownList, widget.shotIndex)],
				),
			],
		);
	}


	Widget _buildPin(int pinNumber, List<bool> pinsDownList, int shotIndex) {
		final index = pinNumber - 1;
		final isDown = pinsDownList[index];
		final activeGame = _sessionController.currentSession!.games[_sessionController.activeGameIndex];
		final frame = activeGame.frames[widget.frameIndex];
		Color pinColor;
		
		// For shot 2, check if it's been submitted - if not, use shot 1 colors
		final isShotSubmitted = frame.shots.length >= shotIndex;
		
		if (shotIndex == 1 || (shotIndex == 2 && !isShotSubmitted)) {
			// Shot 1 colors OR shot 2 before submission: dark grey for knocked down, purple for standing
			pinColor = isDown 
				? const Color.fromRGBO(100, 100, 100, 1) // dark grey - knocked down
				: const Color.fromRGBO(142, 124, 195, 1); // purple - standing
		} else {
			// Shot 2 after submission: show perspective colors (purple for available, red for standing)
			final currentShot = frame.shots.length >= shotIndex ? frame.shots[shotIndex - 1] : null;
			final isSpare = currentShot != null && (currentShot.pins & 0x3FF) == 0;
			
			if (isSpare) {
				// Spare on shot 2: all pins knocked down - show dark grey
				pinColor = const Color.fromRGBO(100, 100, 100, 1);
			} else {
				final previousShot = frame.shots.isNotEmpty ? frame.shots.first : null;
				
				if (previousShot == null) {
					// No previous shot, treat as shot 1
					pinColor = isDown 
						? const Color.fromRGBO(100, 100, 100, 1)
						: const Color.fromRGBO(142, 124, 195, 1);
				} else {
					final wasAvailable = previousShot.pinsState[index]; // true = was standing after shot 1
					if (!wasAvailable) {
						// Pin was knocked down in shot 1: dark grey
						pinColor = const Color.fromRGBO(100, 100, 100, 1);
					} else if (isDown) {
						// Pin was available but got knocked down in shot 2: purple
						pinColor = const Color.fromRGBO(142, 124, 195, 1);
					} else {
						// Pin is still standing after shot 2: red
						pinColor = const Color.fromARGB(255, 255, 0, 0);
					}
				}
			}
		}
		
		return Container(
			width: 18,
			height: 18,
			margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
			decoration: BoxDecoration(
				color: pinColor,
				shape: BoxShape.circle,
				border: Border.all(color: Colors.black, width: 0.5),
			),
		);
	}


	Widget _buildInfoBar(double stance, double board, double speed, int ball, {bool showEmptyValues = false}) {
		const impactAbbreviations = <int, String>{
			0: 'GUT',
			11: 'R',
			13: 'L',
			16: 'LP',
			17: 'P',
			18: 'HP',
			20: 'N',
			21: 'H',
			23: 'BR',
			27: 'LF',
		};
		final roundedImpact = board.round();
		final bool isWholeImpact = (board - roundedImpact).abs() < 0.001;
		final boardDisplay = isWholeImpact
			? (impactAbbreviations[roundedImpact] ?? roundedImpact.toString())
			: board.toStringAsFixed(1);
		final ballDisplay = showEmptyValues ? '' : ball.toString();
		final stanceDisplay = showEmptyValues ? '' : stance.toStringAsFixed(1);
		final impactDisplay = showEmptyValues ? '' : boardDisplay;
		final speedDisplay = showEmptyValues ? '' : speed.toStringAsFixed(1);
		return SizedBox(
			height: 110,
			width: 240,
			child: Stack(
				alignment: Alignment.bottomCenter,
				children: [
					Positioned(
						left: 4,
						bottom: 42,
						child: _buildInfoOrb('Ball', ballDisplay, 54),
					),
					Positioned(
						left: 56,
						bottom: 14,
						child: _buildInfoOrb('Stance', stanceDisplay, 56),
					),
					Positioned(
						right: 56,
						bottom: 14,
						child: _buildInfoOrb('Impact', impactDisplay, 56),
					),
					Positioned(
						right: 4,
						bottom: 42,
						child: _buildInfoOrb('Speed', speedDisplay, 54),
					),
				],
			),
		);
	}

	Widget _buildInfoOrb(String label, String value, double size) {
		return Container(
			width: size,
			height: size,
			decoration: BoxDecoration(
				shape: BoxShape.circle,
				gradient: const LinearGradient(
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
					colors: [
						Color.fromRGBO(236, 236, 236, 1),
						Color.fromRGBO(188, 188, 188, 1),
					],
				),
				border: Border.all(color: Colors.black, width: 0.9),
				boxShadow: [
					BoxShadow(
						color: Colors.black.withOpacity(0.28),
						blurRadius: 6,
						offset: const Offset(0, 2),
					),
				],
			),
			child: Padding(
				padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Text(
							label,
							maxLines: 1,
							overflow: TextOverflow.ellipsis,
							style: const TextStyle(
								color: Colors.black,
								fontSize: 10,
								fontWeight: FontWeight.w700,
								height: 1,
							),
						),
						const SizedBox(height: 2),
						Text(
							value,
							maxLines: 1,
							overflow: TextOverflow.ellipsis,
							style: const TextStyle(
								color: Colors.black,
								fontSize: 14,
								fontWeight: FontWeight.bold,
								height: 1,
							),
						),
					],
				),
			),
		);
	}


	@override
	Widget build(BuildContext context) {
		final displayFrameNumber = widget.frameIndex + 1;
		final activeGame = _sessionController.currentSession!.games[_sessionController.activeGameIndex];
		final frame = activeGame.frames[widget.frameIndex];
		final shotToDisplay = frame.shots.length >= widget.shotIndex
			? frame.shots[widget.shotIndex - 1]
			: null;
		final isReadOnly = shotToDisplay?.isReadOnly ?? false;

		return Scaffold(
			backgroundColor: widget.color,
			extendBodyBehindAppBar: true,
			body: Center(
				child: Container(
					width: 280,
					height: 280,
					decoration: BoxDecoration(
						color: widget.color,
						shape: BoxShape.circle,
					),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.start,
						children: [
							GestureDetector(
								onTap: isReadOnly ? null : _openShotPage,
								behavior: HitTestBehavior.opaque,
								child: Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										const SizedBox(height: 14),
										Text(
											'Frame $displayFrameNumber — Shot ${widget.shotIndex}${isReadOnly ? ' (View)' : ''}',
											style: TextStyle(
												color: isReadOnly ? Colors.grey : Colors.white,
												fontSize: 14,
												fontWeight: FontWeight.bold,
											),
										),
										const SizedBox(height: 8),
										_buildPinDisplay(pinsDown),
										const SizedBox(height: 4),
									],
								),
							),
							Expanded(
								child: Center(
									child: Transform.scale(
										scale: 0.72,
										child: _buildInfoBar(
											stance,
											board,
											speed,
											ball,
											showEmptyValues: _showEmptyInfoBarValues,
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
}