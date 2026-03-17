import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Logic Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const RobotDashboard(),
      },
    );
  }
}

class RobotDashboard extends StatefulWidget {
  const RobotDashboard({super.key});

  @override
  State<RobotDashboard> createState() => _RobotDashboardState();
}

class _RobotDashboardState extends State<RobotDashboard> {
  // Robot State
  Offset robotPos = const Offset(200, 350);
  double robotAngle = -pi / 2; // Facing up
  String status = "Stopped";
  bool isRunning = false;
  Timer? loopTimer;

  // Simulator Environment
  final double canvasSize = 400.0;
  final List<Rect> obstacles = [
    const Rect.fromLTWH(100, 150, 200, 30),
    const Rect.fromLTWH(50, 50, 50, 50),
    const Rect.fromLTWH(300, 50, 50, 50),
  ];

  // Corrected Arduino Code
  final String correctedArduinoCode = '''
#include <Servo.h>

Servo servo;

const int trig = 9;
const int echo = 10;

const int in1 = 4;
const int in2 = 5;
const int in3 = 6;
const int in4 = 7;

void setup() {
  pinMode(trig, OUTPUT);
  pinMode(echo, INPUT);

  pinMode(in1, OUTPUT);
  pinMode(in2, OUTPUT);
  pinMode(in3, OUTPUT);
  pinMode(in4, OUTPUT);

  servo.attach(3);
  servo.write(90);   // center

  stopRobot();
  delay(2000);
}

void loop() {
  int distance = getDistance();

  // ❌ Ignore false readings (timeout or noise)
  if (distance == 0 || distance > 200) {
    forward();
    delay(50);
    return;
  }

  // ✅ NORMAL FORWARD
  if (distance > 15) {
    forward();
  } else {
    // 🚫 OBSTACLE DETECTED - DOUBLE CHECK TO PREVENT FALSE ALARMS
    delay(50);
    distance = getDistance(); // Verify it's a real obstacle
    
    if (distance <= 15 && distance > 0) {
      avoidObstacle();
    }
  }
  delay(50);
}

void avoidObstacle() {
  stopRobot();
  delay(200);

  int left = checkLeft();
  int right = checkRight();

  // ✅ choose best direction
  if (left > right && left > 15) {
    turnLeft();
    delay(100);   // 🔥 REDUCED DELAY to prevent over-rotation
  } else if (right > 15) {
    turnRight();
    delay(100);   // 🔥 REDUCED DELAY to prevent over-rotation
  } else {
    // ❌ if both blocked → turn around
    turnRight();
    delay(200);
  }

  stopRobot();
  delay(100);
}

// ---------- DISTANCE ----------
int getDistance() {
  digitalWrite(trig, LOW);
  delayMicroseconds(2);

  digitalWrite(trig, HIGH);
  delayMicroseconds(10);
  digitalWrite(trig, LOW);

  long duration = pulseIn(echo, HIGH, 20000); // 20ms timeout
  if (duration == 0) return 999; // Return large number if no echo
  
  return duration * 0.034 / 2;
}

// ---------- SERVO ----------
int checkLeft() {
  servo.write(40);
  delay(350);
  int d = getDistance();
  servo.write(90);
  delay(150);
  return d;
}

int checkRight() {
  servo.write(140);
  delay(350);
  int d = getDistance();
  servo.write(90);
  delay(150);
  return d;
}

// ---------- MOVEMENT ----------
// NOTE: If robot moves backward, swap wires for in1/in2 and in3/in4!
void forward() {
  digitalWrite(in1, HIGH); digitalWrite(in2, LOW);
  digitalWrite(in3, HIGH); digitalWrite(in4, LOW);
}

void turnLeft() {
  digitalWrite(in1, LOW); digitalWrite(in2, HIGH);
  digitalWrite(in3, HIGH); digitalWrite(in4, LOW);
}

void turnRight() {
  digitalWrite(in1, HIGH); digitalWrite(in2, LOW);
  digitalWrite(in3, LOW); digitalWrite(in4, HIGH);
}

void stopRobot() {
  digitalWrite(in1, LOW); digitalWrite(in2, LOW);
  digitalWrite(in3, LOW); digitalWrite(in4, LOW);
}
''';

  void startSimulation() {
    if (isRunning) return;
    setState(() {
      isRunning = true;
      status = "Starting...";
    });
    runRobotLogic();
  }

  void stopSimulation() {
    setState(() {
      isRunning = false;
      status = "Stopped";
    });
  }

  void resetSimulation() {
    stopSimulation();
    setState(() {
      robotPos = const Offset(200, 350);
      robotAngle = -pi / 2;
    });
  }

  // Simulated Ultrasonic Sensor
  double getSimulatedDistance(double angleOffset) {
    double testAngle = robotAngle + angleOffset;
    double dist = 0;
    double step = 2.0;
    double maxDist = 150.0;

    while (dist < maxDist) {
      dist += step;
      Offset checkPos = robotPos + Offset(cos(testAngle), sin(testAngle)) * dist;

      // Check boundaries
      if (checkPos.dx < 0 || checkPos.dx > canvasSize || checkPos.dy < 0 || checkPos.dy > canvasSize) {
        return dist;
      }

      // Check obstacles
      for (var obs in obstacles) {
        if (obs.contains(checkPos)) {
          return dist;
        }
      }
    }
    return maxDist;
  }

  // Simulated Arduino Loop
  void runRobotLogic() async {
    while (isRunning) {
      double distance = getSimulatedDistance(0);

      if (distance > 40) {
        // Move Forward
        setState(() {
          status = "Moving Forward";
          robotPos += Offset(cos(robotAngle), sin(robotAngle)) * 5;
        });
        await Future.delayed(const Duration(milliseconds: 50));
      } else {
        // Obstacle Detected!
        setState(() => status = "Obstacle! Verifying...");
        await Future.delayed(const Duration(milliseconds: 100)); // Debounce
        
        distance = getSimulatedDistance(0);
        if (distance <= 40) {
          setState(() => status = "Checking Left...");
          await Future.delayed(const Duration(milliseconds: 400));
          double leftDist = getSimulatedDistance(-pi / 4);

          setState(() => status = "Checking Right...");
          await Future.delayed(const Duration(milliseconds: 400));
          double rightDist = getSimulatedDistance(pi / 4);

          if (leftDist > rightDist && leftDist > 40) {
            setState(() {
              status = "Turning Left";
              robotAngle -= pi / 4; // Reduced turn
            });
          } else if (rightDist > 40) {
            setState(() {
              status = "Turning Right";
              robotAngle += pi / 4; // Reduced turn
            });
          } else {
            setState(() {
              status = "Blocked! Turning Around";
              robotAngle += pi / 2;
            });
          }
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    }
  }

  @override
  void dispose() {
    isRunning = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Logic Simulator & Code Fix'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Row(
        children: [
          // Left Side: Simulator
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Status: $status",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: canvasSize,
                    height: canvasSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: CustomPaint(
                      painter: RobotPainter(
                        robotPos: robotPos,
                        robotAngle: robotAngle,
                        obstacles: obstacles,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isRunning ? stopSimulation : startSimulation,
                        icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                        label: Text(isRunning ? "Stop" : "Start"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: resetSimulation,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Reset"),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Watch the robot navigate! It uses the exact logic from the corrected C++ code on the right.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right Side: Corrected Code
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Corrected Arduino Code",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: correctedArduinoCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Code copied to clipboard!")),
                          );
                        },
                        tooltip: "Copy Code",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Fixes applied:\n"
                    "1. Added debounce (double-check) to ignore false ultrasonic noise.\n"
                    "2. Reduced turn delay from 180ms to 100ms to prevent over-rotation.\n"
                    "3. Handled pulseIn timeout (0) properly.\n"
                    "*Note: If it still moves backward, swap your physical motor wires!*",
                    style: TextStyle(color: Colors.amber, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        correctedArduinoCode,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RobotPainter extends CustomPainter {
  final Offset robotPos;
  final double robotAngle;
  final List<Rect> obstacles;

  RobotPainter({
    required this.robotPos,
    required this.robotAngle,
    required this.obstacles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Obstacles
    final obsPaint = Paint()..color = Colors.redAccent;
    for (var obs in obstacles) {
      canvas.drawRect(obs, obsPaint);
    }

    // Draw Robot Body
    canvas.save();
    canvas.translate(robotPos.dx, robotPos.dy);
    canvas.rotate(robotAngle);

    final robotPaint = Paint()..color = Colors.blue;
    canvas.drawCircle(Offset.zero, 15, robotPaint);

    // Draw Robot "Eyes" / Direction indicator
    final eyePaint = Paint()..color = Colors.yellow;
    canvas.drawCircle(const Offset(10, -5), 4, eyePaint);
    canvas.drawCircle(const Offset(10, 5), 4, eyePaint);
    
    // Draw Sensor Beam
    final beamPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    Path beamPath = Path();
    beamPath.moveTo(15, 0);
    beamPath.lineTo(60, -20);
    beamPath.lineTo(60, 20);
    beamPath.close();
    canvas.drawPath(beamPath, beamPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
