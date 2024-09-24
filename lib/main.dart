import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

void main() {
  runApp(const KaleidoFlowApp());
}

class KaleidoFlowApp extends StatelessWidget {
  const KaleidoFlowApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Disable the debug banner for a cleaner look
    return MaterialApp(
      title: 'KaleidoFlow',
      theme: ThemeData.dark(),
      home: const KaleidoFlowScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class KaleidoFlowScreen extends StatefulWidget {
  const KaleidoFlowScreen({Key? key}) : super(key: key);

  @override
  _KaleidoFlowScreenState createState() => _KaleidoFlowScreenState();
}

class _KaleidoFlowScreenState extends State<KaleidoFlowScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  final List<KaleidoElement> _elements = [];
  final Random _random = Random();

  // User-controlled settings
  Color _currentColor = Colors.blueAccent;
  double _currentSize = 20.0;
  double _currentSpeed = 1.0;
  int _symmetryCount = 6; // Number of symmetry axes

  // Sound Effects
  final AudioPlayer _soundPlayer = AudioPlayer();
  final AudioPlayer _backgroundPlayer = AudioPlayer(); // For background music

  // Screenshot Controller
  final ScreenshotController _screenshotController = ScreenshotController();

  // Timer for generating random elements
  Timer? _elementTimer;

  // Starfield Background
  final List<Star> _stars = [];
  Timer? _starTimer;

  // Variables to handle gesture tracking
  Offset? _lastFocalPoint;

  // Palette management
  final List<List<Color>> _palettes = [
    [Colors.blueAccent, Colors.purpleAccent, Colors.redAccent],
    [Colors.greenAccent, Colors.tealAccent, Colors.cyanAccent],
    [Colors.orangeAccent, Colors.amberAccent, Colors.yellowAccent],
    [Colors.pinkAccent, Colors.limeAccent, Colors.indigoAccent],
    [Colors.deepPurple, Colors.indigo, Colors.teal, Colors.orange, Colors.pink],
  ];
  int _currentPaletteIndex = 0;

  // Action history for Undo/Redo
  final List<List<KaleidoElement>> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller for continuous rendering
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(() {
        _updateElements();
        _updateStars();
      })
      ..repeat();

    // Start generating random art elements periodically
    _startGeneratingElements();

    // Initialize starfield background after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStarfield();
    });

    // Start background music
    _startBackgroundMusic();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _soundPlayer.dispose();
    _backgroundPlayer.dispose();
    _elementTimer?.cancel();
    _starTimer?.cancel();
    super.dispose();
  }

  // Function to update the position of each element
  void _updateElements() {
    setState(() {
      for (var element in _elements) {
        element.updatePosition();
        element.updateColorTransition();
      }
      // Remove elements that are out of bounds or faded
      _elements.removeWhere((element) => element.isDead());
    });
  }

  // Function to initialize the starfield background
  void _initializeStarfield() {
    final Size size = MediaQuery.of(context).size;
    for (int i = 0; i < 100; i++) {
      _stars.add(Star(
        position: Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        ),
        size: _random.nextDouble() * 2 + 1,
        speed: _random.nextDouble() * 0.5 + 0.1,
        color: Colors.white.withOpacity(_random.nextDouble()),
      ));
    }
    // Update stars periodically
    _starTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _updateStars();
    });
  }

  // Function to update stars' positions
  void _updateStars() {
    setState(() {
      for (var star in _stars) {
        star.updatePosition();
      }
      // Reset stars that move off-screen
      for (var star in _stars) {
        if (star.position.dy > MediaQuery.of(context).size.height) {
          star.position = Offset(
            _random.nextDouble() * MediaQuery.of(context).size.width,
            -star.size,
          );
        }
      }
    });
  }

  // Function to play sound from network URL
  Future<void> _playSound(String url) async {
    try {
      await _soundPlayer.setUrl(url);
      await _soundPlayer.play();
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  // Function to start background music
  Future<void> _startBackgroundMusic() async {
    try {
      await _backgroundPlayer.setUrl('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3');
      await _backgroundPlayer.setLoopMode(LoopMode.all);
      await _backgroundPlayer.play();
    } catch (e) {
      debugPrint('Error playing background music: $e');
    }
  }

  // Function to add a new kaleido element
  void _addKaleidoElement(Offset position) {
    setState(() {
      _elements.add(
        KaleidoElement(
          position: position,
          color: _currentColor,
          size: _currentSize,
          shape: Shape.values[_random.nextInt(Shape.values.length)],
          velocity: Offset(
            (_random.nextDouble() - 0.5) * _currentSpeed,
            (_random.nextDouble() - 0.5) * _currentSpeed,
          ),
        ),
      );

      // Manage history for Undo functionality
      if (_historyIndex < _history.length - 1) {
        _history.removeRange(_historyIndex + 1, _history.length);
      }
      _history.add(List.from(_elements));
      _historyIndex++;
    });
  }

  // Handle user tapping on the canvas
  void _handleTap(TapUpDetails details) {
    _addKaleidoElement(details.localPosition);
    // Play tap sound
    _playSound('https://www.soundjay.com/buttons/sounds/button-16.mp3');
  }

  // Handle user scaling and panning on the canvas
  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // Handle scaling
    setState(() {
      _currentSize = (_currentSize * details.scale).clamp(10.0, 50.0);
      _currentSpeed = (_currentSpeed * details.scale).clamp(0.5, 5.0);
    });
    // Play scale sound
    _playSound('https://www.soundjay.com/buttons/sounds/button-10.mp3');

    // Handle panning by adding shapes based on movement
    if (_lastFocalPoint != null) {
      final Offset delta = details.focalPoint - _lastFocalPoint!;
      final double distance = delta.distance;
      if (distance > 10) { // Threshold to prevent too many shapes
        _addKaleidoElement(details.focalPoint);
        // Play add shape sound
        _playSound('https://www.soundjay.com/buttons/sounds/button-09.mp3');
      }
      _lastFocalPoint = details.focalPoint;
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
  }

  // Cycle through predefined color palettes
  void _cycleColorPalette() {
    setState(() {
      _currentPaletteIndex = (_currentPaletteIndex + 1) % _palettes.length;
      _currentColor = _palettes[_currentPaletteIndex][_random.nextInt(_palettes[_currentPaletteIndex].length)];
    });
    // Play palette change sound
    _playSound('https://www.soundjay.com/buttons/sounds/button-5.mp3');
  }

  // Clear the canvas
  Future<void> _clearCanvas() async {
    setState(() {
      _elements.clear();
      _history.clear();
      _historyIndex = -1;
    });
    // Play clear sound
    await _playSound('https://www.soundjay.com/buttons/sounds/button-3.mp3');
  }

  // Change symmetry count
  void _changeSymmetry(int delta) {
    setState(() {
      _symmetryCount = (_symmetryCount + delta).clamp(2, 12);
    });
    // Play symmetry change sound
    _playSound('https://www.soundjay.com/buttons/sounds/button-4.mp3');
  }

  // Function to capture and save the artwork
  Future<void> _captureAndSave() async {
    // Check and request storage permissions
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to save artwork.')),
        );
        return;
      }
    }

    // Capture screenshot
    final image = await _screenshotController.capture();
    if (image == null) return;

    // Get directory
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
      // For Android 11 and above, use the Pictures directory
      if (directory != null) {
        directory = Directory('/storage/emulated/0/Pictures/KaleidoFlow');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    }

    if (directory == null) return;

    final String path = '${directory.path}/kaleido_flow_${DateTime.now().millisecondsSinceEpoch}.png';
    final File file = File(path);
    await file.writeAsBytes(image);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Artwork saved to ${file.path}')),
    );

    // Play save sound
    await _playSound('https://www.soundjay.com/buttons/sounds/button-2.mp3');
  }

  // Function to share the artwork
  // Future<void> _shareArtwork() async {
  //   // Capture screenshot
  //   final image = await _screenshotController.capture();
  //   if (image == null) return;

  //   // Save to temporary directory
  //   final directory = await getTemporaryDirectory();
  //   final String path = '${directory.path}/kaleido_flow_share.png';
  //   final File file = File(path);
  //   await file.writeAsBytes(image);

  //   // Share the image
  //   await Share.shareXFiles([path], text: 'Check out my KaleidoFlow artwork!');
  // }

  // Function to undo the last action
  void _undo() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _elements
          ..clear()
          ..addAll(_history[_historyIndex]);
      });
      _playSound('https://www.soundjay.com/buttons/sounds/button-7.mp3');
    }
  }

  // Function to redo the undone action
  void _redo() {
    if (_historyIndex < _history.length - 1) {
      setState(() {
        _historyIndex++;
        _elements
          ..clear()
          ..addAll(_history[_historyIndex]);
      });
      _playSound('https://www.soundjay.com/buttons/sounds/button-8.mp3');
    }
  }

  // Function to start generating random elements periodically
  void _startGeneratingElements() {
    _elementTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) return;

      // Generate a random position within the screen bounds
      final Size size = MediaQuery.of(context).size;
      Offset position = Offset(
        _random.nextDouble() * size.width,
        _random.nextDouble() * size.height,
      );

      _addKaleidoElement(position);
    });
  }

  // Function to reveal hidden Easter Egg features
  void _checkForEasterEggs(Offset position) {
    // Example: If user taps five times in quick succession in a specific area, unlock a secret theme
    // This is a placeholder; implement your own logic as desired
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent AppBar for overlay controls
      appBar: AppBar(
        title: const Text('KaleidoFlow'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _cycleColorPalette,
            tooltip: 'Change Color Palette',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearCanvas,
            tooltip: 'Clear Canvas',
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _redo,
            tooltip: 'Redo',
          ),
          // IconButton(
          //   icon: const Icon(Icons.share),
          //   // onPressed: _shareArtwork,
          //   tooltip: 'Share Artwork',
          // ),
          IconButton(
            icon: const Icon(Icons.repeat),
            onPressed: () => _changeSymmetry(1),
            tooltip: 'Increase Symmetry',
          ),
          IconButton(
            icon: const Icon(Icons.repeat_one),
            onPressed: () => _changeSymmetry(-1),
            tooltip: 'Decrease Symmetry',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _captureAndSave,
            tooltip: 'Save Artwork',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Screenshot(
        controller: _screenshotController,
        child: Stack(
          children: [
            // Starfield Background
            CustomPaint(
              painter: StarfieldPainter(stars: _stars),
              child: Container(),
            ),
            // Kaleido Elements
            GestureDetector(
              onTapUp: _handleTap,
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onScaleEnd: _handleScaleEnd,
              child: CustomPaint(
                painter: KaleidoPainter(
                  elements: _elements,
                  symmetryCount: _symmetryCount,
                ),
                child: Container(),
              ),
            ),
          ],
        ),
      ),
      // Overlay Controls (Sliders)
      bottomNavigationBar: Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Size Slider
            Row(
              children: [
                const Icon(Icons.aspect_ratio, color: Colors.white),
                Expanded(
                  child: Slider(
                    activeColor: Colors.blueAccent,
                    inactiveColor: Colors.grey,
                    value: _currentSize,
                    min: 10.0,
                    max: 100.0,
                    onChanged: (value) {
                      setState(() {
                        _currentSize = value;
                      });
                    },
                  ),
                ),
                Text(
                  '${_currentSize.toInt()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            // Speed Slider
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.white),
                Expanded(
                  child: Slider(
                    activeColor: Colors.greenAccent,
                    inactiveColor: Colors.grey,
                    value: _currentSpeed,
                    min: 0.5,
                    max: 10.0,
                    onChanged: (value) {
                      setState(() {
                        _currentSpeed = value;
                      });
                    },
                  ),
                ),
                Text(
                  '${_currentSpeed.toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            // Symmetry Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Symmetry: ',
                  style: TextStyle(color: Colors.white),
                ),
                DropdownButton<int>(
                  value: _symmetryCount,
                  dropdownColor: Colors.black87,
                  items: List.generate(11, (index) => index + 2)
                      .map(
                        (count) => DropdownMenuItem<int>(
                          value: count,
                          child: Text(
                            '$count',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _symmetryCount = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Enumeration for different shapes
enum Shape { circle, square, triangle, star, hexagon, pentagon, octagon, heart }

// Class representing each kaleido element
class KaleidoElement {
  Offset position;
  Color color;
  final double size;
  final Shape shape;
  Offset velocity;
  double opacity;

  // For color transitions
  Color startColor;
  Color endColor;
  double colorTransitionProgress;

  KaleidoElement({
    required this.position,
    required this.color,
    required this.size,
    required this.shape,
    required this.velocity,
    this.opacity = 1.0,
  })  : startColor = color,
        endColor = Colors.white,
        colorTransitionProgress = 0.0;

  // Update the position based on velocity and fade out
  void updatePosition() {
    position += velocity;
    opacity -= 0.005; // Fade out over time
  }

  // Update color transition
  void updateColorTransition() {
    colorTransitionProgress += 0.005;
    if (colorTransitionProgress >= 1.0) {
      // Swap start and end colors for continuous transition
      Color temp = startColor;
      startColor = endColor;
      endColor = temp;
      colorTransitionProgress = 0.0;
    }
    color = Color.lerp(startColor, endColor, colorTransitionProgress)!;
  }

  // Check if the element is dead (fully faded or out of bounds)
  bool isDead([Size? canvasSize]) {
    if (opacity <= 0.0) return true;
    if (canvasSize != null) {
      return position.dx < -size ||
          position.dx > canvasSize.width + size ||
          position.dy < -size ||
          position.dy > canvasSize.height + size;
    }
    return false;
  }
}

// Class representing a star in the starfield background
class Star {
  Offset position;
  final double size;
  final double speed;
  final Color color;

  Star({
    required this.position,
    required this.size,
    required this.speed,
    required this.color,
  });

  void updatePosition() {
    position = Offset(position.dx, position.dy + speed);
  }
}

// CustomPainter for the starfield background
class StarfieldPainter extends CustomPainter {
  final List<Star> stars;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  StarfieldPainter({required this.stars});

  @override
  void paint(Canvas canvas, Size size) {
    for (var star in stars) {
      _paint.color = star.color;
      canvas.drawCircle(star.position, star.size, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) => true;
}

// CustomPainter for drawing kaleido elements with symmetry
class KaleidoPainter extends CustomPainter {
  final List<KaleidoElement> elements;
  final int symmetryCount;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  KaleidoPainter({required this.elements, required this.symmetryCount});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double angle = (2 * pi) / symmetryCount;

    for (var element in elements) {
      for (int i = 0; i < symmetryCount; i++) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle * i);
        canvas.translate(element.position.dx - center.dx, element.position.dy - center.dy);

        // Apply pulsing and rotating animations
        double pulse = 1 + 0.3 * sin(DateTime.now().millisecondsSinceEpoch / 500.0);
        double rotation = pi / 180 * (DateTime.now().millisecondsSinceEpoch / 10.0);

        canvas.rotate(rotation);

        // Apply gradient fill
        Rect rect = Rect.fromCenter(
          center: Offset.zero,
          width: element.size * pulse,
          height: element.size * pulse,
        );

        Shader shader = LinearGradient(
          colors: [
            element.color.withOpacity(0.8),
            element.color.withOpacity(0.0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);

        Paint shapePaint = Paint()
          ..shader = shader
          ..style = PaintingStyle.fill;

        // Draw the shape
        switch (element.shape) {
          case Shape.circle:
            canvas.drawCircle(Offset.zero, element.size / 2 * pulse, shapePaint);
            break;
          case Shape.square:
            canvas.drawRect(
              Rect.fromCenter(
                center: Offset.zero,
                width: element.size * pulse,
                height: element.size * pulse,
              ),
              shapePaint,
            );
            break;
          case Shape.triangle:
            Path path = Path();
            path.moveTo(0, -element.size / 2 * pulse);
            path.lineTo(-element.size / 2 * pulse, element.size / 2 * pulse);
            path.lineTo(element.size / 2 * pulse, element.size / 2 * pulse);
            path.close();
            canvas.drawPath(path, shapePaint);
            break;
          case Shape.star:
            _drawStar(canvas, Offset.zero, element.size / 2 * pulse, shapePaint);
            break;
          case Shape.hexagon:
            _drawHexagon(canvas, Offset.zero, element.size / 2 * pulse, shapePaint);
            break;
          case Shape.pentagon:
            _drawPentagon(canvas, Offset.zero, element.size / 2 * pulse, shapePaint);
            break;
          case Shape.octagon:
            _drawOctagon(canvas, Offset.zero, element.size / 2 * pulse, shapePaint);
            break;
          case Shape.heart:
            _drawHeart(canvas, Offset.zero, element.size / 2 * pulse, shapePaint);
            break;
        }

        canvas.restore();
      }
    }
  }

  // Function to draw a star
  void _drawStar(Canvas canvas, Offset position, double radius, Paint paint) {
    final Path path = Path();
    const int points = 5;
    double angle = pi / 2;

    for (int i = 0; i < points * 2; i++) {
      double r = (i % 2 == 0) ? radius : radius / 2;
      double x = r * cos(angle);
      double y = r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += pi / points;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // Function to draw a hexagon
  void _drawHexagon(Canvas canvas, Offset position, double radius, Paint paint) {
    final Path path = Path();
    double angle = 0;

    for (int i = 0; i < 6; i++) {
      double x = radius * cos(angle);
      double y = radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += pi / 3;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // Function to draw a pentagon
  void _drawPentagon(Canvas canvas, Offset position, double radius, Paint paint) {
    final Path path = Path();
    double angle = pi / 2;

    for (int i = 0; i < 5; i++) {
      double x = radius * cos(angle);
      double y = radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += 2 * pi / 5;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // Function to draw an octagon
  void _drawOctagon(Canvas canvas, Offset position, double radius, Paint paint) {
    final Path path = Path();
    double angle = pi / 8;

    for (int i = 0; i < 8; i++) {
      double x = radius * cos(angle);
      double y = radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += pi / 4;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // Function to draw a heart
  void _drawHeart(Canvas canvas, Offset position, double radius, Paint paint) {
    final Path path = Path();
    path.moveTo(0, radius / 2);
    path.cubicTo(radius, -radius / 2, radius, radius, 0, radius * 1.5);
    path.cubicTo(-radius, radius, -radius, -radius / 2, 0, radius / 2);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant KaleidoPainter oldDelegate) => true;
}
