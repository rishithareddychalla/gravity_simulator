import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GravitySimulatorPage extends StatefulWidget {
  const GravitySimulatorPage({super.key});

  @override
  State<GravitySimulatorPage> createState() => _GravitySimulatorPageState();
}

class _GravitySimulatorPageState extends State<GravitySimulatorPage>
    with SingleTickerProviderStateMixin {
  final List<Ball> balls = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? timer;
  Timer? holdTimer;

  double gravityStrength = 9.8;
  double impulseMultiplier = 1.4;
  double growingRadius = 30;
  final double maxRadius = 80;
  int ballCount = 0;

  bool _useRandomSize = true;
  bool _isLongPressing = false;
  Offset? _tempBallPosition;
  Color? _tempBallColor;
  String? _tempBallEmoji;

  late final AnimationController _rippleController;
  late final Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _rippleAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut),
    );

    timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      setState(() {
        for (final ball in balls) {
          if (!ball.isDragging) {
            ball.vy += gravityStrength * 0.1;
            ball.x += ball.vx;
            ball.y += ball.vy;

            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;

            if (ball.y > screenHeight - ball.radius) {
              ball.y = screenHeight - ball.radius;
              ball.vy = -ball.vy * 0.7;
            }
            if (ball.x > screenWidth - ball.radius) {
              ball.x = screenWidth - ball.radius;
              ball.vx = -ball.vx * 0.7;
            } else if (ball.x < ball.radius) {
              ball.x = ball.radius;
              ball.vx = -ball.vx * 0.7;
            }
          }
        }

        // Ball collisions & gravity-like attraction
        for (int i = 0; i < balls.length; i++) {
          for (int j = i + 1; j < balls.length; j++) {
            final dx = balls[j].x - balls[i].x;
            final dy = balls[j].y - balls[i].y;
            final dist = sqrt(dx * dx + dy * dy);
            final minDist = (balls[i].radius + balls[j].radius) / 2;

            if (dist < minDist) {
              final nx = dist > 0 ? dx / dist : 1.0;
              final ny = dist > 0 ? dy / dist : 0.0;
              final rvx = balls[j].vx - balls[i].vx;
              final rvy = balls[j].vy - balls[i].vy;
              final dot = rvx * nx + rvy * ny;
              if (dot < 0) {
                final impulse = -dot * impulseMultiplier;
                balls[i].vx -= impulse * nx * 0.7;
                balls[i].vy -= impulse * ny * 0.7;
                balls[j].vx += impulse * nx * 0.7;
                balls[j].vy += impulse * ny * 0.7;
              }
              final overlap = minDist - dist;
              if (dist > 0) {
                balls[i].x -= nx * overlap / 2;
                balls[i].y -= ny * overlap / 2;
                balls[j].x += nx * overlap / 2;
                balls[j].y += ny * overlap / 2;
              }
            } else if (dist > 0) {
              final force = 30 / (dist * dist);
              balls[i].vx += force * dx / dist;
              balls[i].vy += force * dy / dist;
              balls[j].vx -= force * dx / dist;
              balls[j].vy -= force * dy / dist;
            }
          }
        }
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    holdTimer?.cancel();
    _audioPlayer.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void startHolding(Offset position) {
    final random = Random();
    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.purpleAccent,
    ];
    final emojis = ['⭐', '🚀', '❤️', '🌈', '⚽'];
    setState(() {
      _isLongPressing = true;
      growingRadius = 30;
      _tempBallPosition = position;
      _tempBallColor = colors[random.nextInt(colors.length)];
      _tempBallEmoji = emojis[random.nextInt(emojis.length)];
    });
    holdTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() {
        if (growingRadius < maxRadius) growingRadius += 2;
      });
    });
  }

  void stopHoldingAndAddBall(Offset position, {bool useRandomSize = false}) {
    holdTimer?.cancel();
    holdTimer = null;

    final random = Random();
    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.purpleAccent,
    ];
    final emojis = ['⭐', '🚀', '❤️', '🌈', '⚽'];

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final radius = useRandomSize
        ? 30 + random.nextDouble() * 20
        : growingRadius;

    setState(() {
      balls.add(
        Ball(
          x: position.dx.clamp(radius, screenWidth - radius),
          y: position.dy.clamp(radius, screenHeight - radius),
          vx: 0,
          vy: 0,
          radius: radius,
          color: colors[random.nextInt(colors.length)],
          emoji: emojis[random.nextInt(emojis.length)],
        ),
      );
      ballCount++;
      growingRadius = 30;
      _isLongPressing = false;
      _tempBallPosition = null;
      _tempBallColor = null;
      _tempBallEmoji = null;
    });

    unawaited(_playPopSound());
  }

  Future<void> _playPopSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/pop.mp3'));
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  void addRandomBurst() {
    final random = Random();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    for (int i = 0; i < 5; i++) {
      stopHoldingAndAddBall(
        Offset(
          random.nextDouble() * screenWidth,
          random.nextDouble() * screenHeight / 2,
        ),
        useRandomSize: true,
      );
    }
  }

  void clearBalls() {
    setState(() {
      balls.clear();
      ballCount = 0;
      growingRadius = 30;
      _isLongPressing = false;
      holdTimer?.cancel();
      holdTimer = null;
      _tempBallPosition = null;
      _tempBallColor = null;
      _tempBallEmoji = null;
    });
  }

  Future<bool> _onWillPop() async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Leave the Fun?',
              style: TextStyle(
                fontFamily: 'Comic Sans MS',
                color: Colors.purple,
              ),
            ),
            content: const Text(
              'Are you sure you want to exit the game?',
              style: TextStyle(fontFamily: 'Comic Sans MS'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No', style: TextStyle(color: Colors.green)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth * 0.05;
    final topSpacing = screenHeight * 0.04;
    final bottomPadding = screenHeight * 0.06;
    final fontSize = screenWidth * 0.04;
    final bool isCompact = screenWidth < 380;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (!_isLongPressing) {
                stopHoldingAndAddBall(
                  details.localPosition,
                  useRandomSize: _useRandomSize,
                );
              }
            },
            onLongPressStart: (details) => startHolding(details.localPosition),
            onLongPressMoveUpdate: (details) {
              setState(() {
                _tempBallPosition = details.localPosition;
                growingRadius = growingRadius.clamp(30, maxRadius);
              });
            },
            onLongPressEnd: (details) {
              stopHoldingAndAddBall(details.localPosition);
            },
            onLongPressCancel: () {
              setState(() {
                growingRadius = 30;
                _isLongPressing = false;
                holdTimer?.cancel();
                holdTimer = null;
                _tempBallPosition = null;
                _tempBallColor = null;
                _tempBallEmoji = null;
              });
            },
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0A0F2C),
                    Color(0xFF111B3A),
                    Color(0xFF1A2A52),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CustomPaint(
                painter: StarryBackgroundPainter(),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.purple.withOpacity(0.15),
                                Colors.transparent,
                              ],
                              radius: 0.9,
                              center: const Alignment(-0.6, -0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_isLongPressing && _tempBallPosition != null)
                      Positioned(
                        left: _tempBallPosition!.dx - growingRadius * 1.2 / 2,
                        top: _tempBallPosition!.dy - growingRadius * 1.2 / 2,
                        child: AnimatedBuilder(
                          animation: _rippleAnimation,
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(
                                growingRadius * 1.2,
                                growingRadius * 1.2,
                              ),
                              painter: RipplePainter(
                                radius: growingRadius * 1.2,
                                opacity: _rippleAnimation.value,
                                color: _tempBallColor ?? Colors.blueAccent,
                              ),
                            );
                          },
                        ),
                      ),
                    if (_isLongPressing &&
                        _tempBallPosition != null &&
                        _tempBallColor != null &&
                        _tempBallEmoji != null)
                      Positioned(
                        left: _tempBallPosition!.dx - growingRadius / 2,
                        top: _tempBallPosition!.dy - growingRadius / 2,
                        child: Container(
                          width: growingRadius,
                          height: growingRadius,
                          decoration: BoxDecoration(
                            color: _tempBallColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _tempBallColor!.withOpacity(0.35),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              _tempBallEmoji!,
                              style: TextStyle(fontSize: growingRadius / 1.5),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: topSpacing,
                      left: padding,
                      right: padding,
                      child: Wrap(
                        spacing: padding * 0.4,
                        runSpacing: padding * 0.3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.cyanAccent,
                              ),
                              SizedBox(width: padding * 0.6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gravity Lab',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: fontSize * 1.3,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Tap to spawn • Hold to grow • Fling to travel',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: fontSize * 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: padding * 0.6,
                              vertical: padding * 0.3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.bubble_chart,
                                  size: 16,
                                  color: Colors.cyanAccent,
                                ),
                                SizedBox(width: padding * 0.3),
                                Text(
                                  'Balls: $ballCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: fontSize * 0.85,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...balls.asMap().entries.map((entry) {
                      final ball = entry.value;
                      return Positioned(
                        left: ball.x - ball.radius / 2,
                        top: ball.y - ball.radius / 2,
                        child: DraggableBall(
                          key: ValueKey(entry.key),
                          ball: ball,
                        ),
                      );
                    }).toList(),
                    Positioned(
                      left: padding,
                      right: padding,
                      bottom: bottomPadding,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            padding: EdgeInsets.all(padding),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.public,
                                          color: Colors.cyanAccent,
                                        ),
                                        SizedBox(width: padding * 0.4),
                                        Text(
                                          'Field Controls',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: fontSize,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: padding * 0.8),
                                    Wrap(
                                      runSpacing: padding * 0.6,
                                      spacing: padding * 0.6,
                                      children: [
                                        SizedBox(
                                          width: isCompact
                                              ? constraints.maxWidth
                                              : constraints.maxWidth / 2 -
                                                    padding * 0.6,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Impulse',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: fontSize * 0.9,
                                                    ),
                                                  ),
                                                  Text(
                                                    impulseMultiplier
                                                        .toStringAsFixed(1),
                                                    style: TextStyle(
                                                      color: Colors.cyanAccent,
                                                      fontSize: fontSize * 0.9,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Slider(
                                                value: impulseMultiplier,
                                                min: 0.5,
                                                max: 2.0,
                                                divisions: 15,
                                                activeColor: Colors.cyanAccent,
                                                inactiveColor: Colors.white12,
                                                label: impulseMultiplier
                                                    .toStringAsFixed(1),
                                                onChanged: (value) {
                                                  setState(() {
                                                    impulseMultiplier = value;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: isCompact
                                              ? constraints.maxWidth
                                              : constraints.maxWidth / 2 -
                                                    padding * 0.6,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Gravity',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: fontSize * 0.9,
                                                    ),
                                                  ),
                                                  Text(
                                                    gravityStrength
                                                        .toStringAsFixed(1),
                                                    style: TextStyle(
                                                      color: Colors.cyanAccent,
                                                      fontSize: fontSize * 0.9,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Slider(
                                                value: gravityStrength,
                                                min: 0,
                                                max: 20,
                                                divisions: 20,
                                                activeColor: Colors.cyanAccent,
                                                inactiveColor: Colors.white12,
                                                label: gravityStrength
                                                    .toStringAsFixed(1),
                                                onChanged: (value) {
                                                  setState(() {
                                                    gravityStrength = value;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: padding * 0.6),
                                    Wrap(
                                      spacing: padding * 0.6,
                                      runSpacing: padding * 0.4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Switch(
                                              value: _useRandomSize,
                                              activeColor: Colors.cyanAccent,
                                              onChanged: (value) {
                                                setState(() {
                                                  _useRandomSize = value;
                                                });
                                              },
                                            ),
                                            Text(
                                              'Random size on tap',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: fontSize * 0.9,
                                              ),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          onPressed: addRandomBurst,
                                          icon: const Icon(
                                            Icons.auto_awesome_motion,
                                            color: Colors.cyanAccent,
                                          ),
                                          tooltip: 'Spawn a 5-ball burst',
                                        ),
                                        IconButton(
                                          onPressed: clearBalls,
                                          icon: const Icon(
                                            Icons.delete_sweep,
                                            color: Colors.redAccent,
                                          ),
                                          tooltip: 'Clear all',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Ball {
  double x, y;
  double vx, vy;
  bool isDragging;
  Color color;
  double radius;
  String emoji;

  Ball({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.isDragging = false,
    this.color = Colors.orange,
    this.radius = 40,
    this.emoji = '⭐',
  });
}

class DraggableBall extends StatefulWidget {
  final Ball ball;

  const DraggableBall({super.key, required this.ball});

  @override
  State<DraggableBall> createState() => _DraggableBallState();
}

class _DraggableBallState extends State<DraggableBall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.bounceOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => widget.ball.isDragging = true,
      onPanUpdate: (details) {
        setState(() {
          widget.ball.x += details.delta.dx;
          widget.ball.y += details.delta.dy;
        });
      },
      onPanEnd: (details) {
        widget.ball.isDragging = false;
        widget.ball.vx = details.velocity.pixelsPerSecond.dx / 20;
        widget.ball.vy = details.velocity.pixelsPerSecond.dy / 20;
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.ball.isDragging ? 1.3 : _animation.value,
            child: Container(
              width: widget.ball.radius,
              height: widget.ball.radius,
              decoration: BoxDecoration(
                color: widget.ball.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.ball.color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  widget.ball.emoji,
                  style: TextStyle(fontSize: widget.ball.radius / 1.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class StarryBackgroundPainter extends CustomPainter {
  final Random random = Random();
  final List<Offset> stars = [];
  final List<double> opacities = [];

  StarryBackgroundPainter() {
    for (int i = 0; i < 30; i++) {
      stars.add(Offset(random.nextDouble() * 1000, random.nextDouble() * 1000));
      opacities.add(0.2 + random.nextDouble() * 0.2);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.2);
    for (int i = 0; i < stars.length; i++) {
      paint.color = Colors.white.withOpacity(opacities[i]);
      canvas.drawCircle(
        Offset(stars[i].dx % size.width, stars[i].dy % size.height),
        1.0 + opacities[i],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RipplePainter extends CustomPainter {
  final double radius;
  final double opacity;
  final Color color;

  RipplePainter({
    required this.radius,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius * 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
