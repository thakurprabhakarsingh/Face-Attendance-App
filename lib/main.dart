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
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const TeacherLoginScreen(),
    );
  }
}

const String baseUrl = "https://prabhakarsingh.pythonanywhere.com";

// ================= 1. TEACHER LOGIN =================
class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/teacher/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _userController.text.trim(),
          'password': _passController.text.trim(),
        }),
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Login failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Authorization Gate')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 80, color: Colors.indigo),
            const SizedBox(height: 24),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: 'Username (e.g. admin)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (e.g. admin123)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Login to System', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
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
        title: Text(teacher['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Subject: ${teacher['subject']}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Teacher ID: #${teacher['id']}",
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text("Register New Student (Global)"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterStudentScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Take Lecture Attendance (Blink Verify)"),
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
              icon: const Icon(Icons.list_alt),
              label: const Text("View My Lecture Attendance Records"),
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

// ================= 3. REGISTER STUDENT =================
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
              SizedBox(
                height: 250,
                child: CameraPreview(_cameraController!),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _captureAndRegister,
              child: _loading ? const CircularProgressIndicator() : const Text("Capture Face & Save"),
            )
          ],
        ),
      ),
    );
  }
}

// ================= 4. BLINK ATTENDANCE VERIFY =================
class MarkAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> teacher;
  const MarkAttendanceScreen({super.key, required this.teacher});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  CameraController? _cameraController;
  bool _verifying = false;
  String _status = "Camera ke aage dekhein aur 1 baar Eye Blink karein";

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
      _status = "Eye open frame capture ho raha hai...";
    });

    try {
      final openFile = await _cameraController!.takePicture();
      String openB64 = base64Encode(await openFile.readAsBytes());

      setState(() => _status = "Ab blink karein (Capture in 700ms)...");
      await Future.delayed(const Duration(milliseconds: 700));

      final blinkFile = await _cameraController!.takePicture();
      String blinkB64 = base64Encode(await blinkFile.readAsBytes());

      setState(() => _status = "Database se match aur Liveness check ho raha hai...");

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
      setState(() => _status = "Verification failed: $e");
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.remove_red_eye),
                  label: const Text("Start Blink & Verify"),
                  onPressed: _verifying ? null : _processBlinkAttendance,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ================= 5. ISOLATED ATTENDANCE VIEW =================
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
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.check, color: Colors.green)),
                        title: Text("${item['name']} (${item['roll_no']})"),
                        subtitle: Text("${item['subject']} | Time: ${item['time']}"),
                        trailing: Text(item['status'],
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
    );
  }
}