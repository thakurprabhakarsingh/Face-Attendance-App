import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera error: $e");
  }
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const TeacherAuthScreen(),
    );
  }
}

const String baseUrl = "https://prabhakarsingh.pythonanywhere.com";

// ================= 1. TEACHER AUTH SCREEN (LOGIN & REGISTER) =================
class TeacherAuthScreen extends StatefulWidget {
  const TeacherAuthScreen({super.key});

  @override
  State<TeacherAuthScreen> createState() => _TeacherAuthScreenState();
}

class _TeacherAuthScreenState extends State<TeacherAuthScreen> {
  bool isLoginMode = true;
  bool _loading = false;

  // Controllers
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Teacher Login Logic
  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage("Kripya username aur password bharein");
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/teacher/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success']) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherDashboard(teacher: data['teacher']),
          ),
        );
      } else {
        _showMessage(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      _showMessage("Network connection error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Teacher Register Logic
  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final subject = _subjectController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || subject.isEmpty || username.isEmpty || password.isEmpty) {
      _showMessage("Sabhi fields bharna zaroori hai");
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/teacher/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'subject': subject,
          'username': username,
          'password': password,
        }),
      );
      final data = jsonDecode(res.body);

      _showMessage(data['message'] ?? '');
      if (data['success']) {
        setState(() {
          isLoginMode = true;
          _passwordController.clear();
        });
      }
    } catch (e) {
      _showMessage("Registration error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance, size: 70, color: Colors.indigo),
              const SizedBox(height: 12),
              Text(
                isLoginMode ? "Teacher Login" : "Teacher Registration",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isLoginMode
                    ? "Apne account me login karein"
                    : "Naya teacher account create karein",
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Extra fields for Register mode
              if (!isLoginMode) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Teacher Full Name",
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: "Subject Name (e.g. Operating Systems)",
                    prefixIcon: Icon(Icons.menu_book),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Username & Password common fields
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 22),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _loading ? null : (isLoginMode ? _handleLogin : _handleRegister),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isLoginMode ? "Login" : "Register Now",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Toggle between Login & Register
              TextButton(
                onPressed: () {
                  setState(() {
                    isLoginMode = !isLoginMode;
                  });
                },
                child: Text(
                  isLoginMode
                      ? "Naye teacher hain? Yahan Register karein"
                      : "Pehle se account hai? Login karein",
                  style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= 2. TEACHER DASHBOARD =================
class TeacherDashboard extends StatelessWidget {
  final Map<String, dynamic> teacher;
  const TeacherDashboard({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(teacher['name'] ?? 'Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const TeacherAuthScreen()),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Subject: ${teacher['subject']}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Teacher ID: #${teacher['id']}",
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text("Register New Student (Global)", style: TextStyle(fontSize: 15)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterStudentScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Take Lecture Attendance (Blink Verify)", style: TextStyle(fontSize: 15)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MarkAttendanceScreen(teacher: teacher),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
              icon: const Icon(Icons.table_chart),
              label: const Text("View My Lecture Attendance Records", style: TextStyle(fontSize: 15)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ViewAttendanceScreen(teacherId: teacher['id']),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ================= 3. REGISTER STUDENT (GLOBAL) =================
class RegisterStudentScreen extends StatefulWidget {
  const RegisterStudentScreen({super.key});

  @override
  State<RegisterStudentScreen> createState() => _RegisterStudentScreenState();
}

class _RegisterStudentScreenState extends State<RegisterStudentScreen> {
  final _rollController = TextEditingController();
  final _nameController = TextEditingController();
  CameraController? _cameraController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.medium,
      );
      _cameraController!.initialize().then((_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndRegister() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    setState(() => _loading = true);

    try {
      final file = await _cameraController!.takePicture();
      Uint8List bytes = await file.readAsBytes();
      String imgBase64 = base64Encode(bytes);

      final res = await http.post(
        Uri.parse('$baseUrl/api/student/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roll_no': _rollController.text.trim(),
          'name': _nameController.text.trim(),
          'image': imgBase64,
        }),
      );

      final data = jsonDecode(res.body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? '')),
      );
      if (data['success']) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Student")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _rollController,
              decoration: const InputDecoration(labelText: "Roll No (Unique)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Student Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            if (_cameraController != null && _cameraController!.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 260,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _captureAndRegister,
                child: _loading ? const CircularProgressIndicator() : const Text("Capture Face & Save"),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ================= 4. BLINK ATTENDANCE VERIFICATION =================
class MarkAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> teacher;
  const MarkAttendanceScreen({super.key, required this.teacher});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  CameraController? _cameraController;
  bool _verifying = false;
  String _status = "Camera ke samne dekhein aur 1 baar Eye Blink karein";

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.medium,
      );
      _cameraController!.initialize().then((_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _processBlinkAttendance() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    setState(() {
      _verifying = true;
      _status = "Open eye frame capture ho raha hai...";
    });

    try {
      final openFile = await _cameraController!.takePicture();
      String openB64 = base64Encode(await openFile.readAsBytes());

      setState(() => _status = "Ab blink karein...");
      await Future.delayed(const Duration(milliseconds: 700));

      final blinkFile = await _cameraController!.takePicture();
      String blinkB64 = base64Encode(await blinkFile.readAsBytes());

      setState(() => _status = "Database matching & liveness check...");

      final res = await http.post(
        Uri.parse('$baseUrl/api/attendance/mark'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'teacher_id': widget.teacher['id'],
          'subject': widget.teacher['subject'],
          'open_eye_image': openB64,
          'blink_eye_image': blinkB64,
        }),
      );

      final data = jsonDecode(res.body);
      setState(() => _status = data['message'] ?? 'Processed');
    } catch (e) {
      setState(() => _status = "Verification error: $e");
    } finally {
      setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.teacher['subject']} Attendance")),
      body: Column(
        children: [
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Expanded(child: CameraPreview(_cameraController!)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(_status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.remove_red_eye),
                    label: const Text("Start Blink & Verify"),
                    onPressed: _verifying ? null : _processBlinkAttendance,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ================= 5. TEACHER ISOLATED ATTENDANCE VIEW =================
class ViewAttendanceScreen extends StatefulWidget {
  final int teacherId;
  const ViewAttendanceScreen({super.key, required this.teacherId});

  @override
  State<ViewAttendanceScreen> createState() => _ViewAttendanceScreenState();
}

class _ViewAttendanceScreenState extends State<ViewAttendanceScreen> {
  List records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/teacher/attendance/${widget.teacherId}'));
      final data = jsonDecode(res.body);
      if (data['success']) {
        setState(() => records = data['records']);
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Lecture Attendance")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? const Center(child: Text("Aaj koi attendance record nahi hai."))
              : ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, i) {
                    final item = records[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.check, color: Colors.white),
                        ),
                        title: Text("${item['name']} (${item['roll_no']})"),
                        subtitle: Text("${item['subject']} | Time: ${item['time']}"),
                        trailing: Text(
                          item['status'],
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}