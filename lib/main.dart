import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

// Emulator ke liye: http://10.0.2.2:5000
// Asli phone ke liye: Laptop ka Wi-Fi IP (e.g. http://192.168.1.10:5000)
const String baseUrl = "https://prabhakarsingh.pythonanywhere.com";

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MaterialApp(
    home: HomeScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

// ---------------- HOME SCREEN ----------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Face Attendance System"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.blueAccent,
              ),
              icon: const Icon(Icons.school, size: 28, color: Colors.white),
              label: const Text("Student Portal", style: TextStyle(fontSize: 20, color: Colors.white)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentRollScreen()));
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.teal,
              ),
              icon: const Icon(Icons.person_pin, size: 28, color: Colors.white),
              label: const Text("Teacher Portal", style: TextStyle(fontSize: 20, color: Colors.white)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDashboardScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- STUDENT: ROLL INPUT SCREEN ----------------
class StudentRollScreen extends StatefulWidget {
  const StudentRollScreen({super.key});

  @override
  State<StudentRollScreen> createState() => _StudentRollScreenState();
}

class _StudentRollScreenState extends State<StudentRollScreen> {
  final TextEditingController _rollController = TextEditingController();
  bool _loading = false;

  Future<void> _verifyRoll() async {
    final roll = _rollController.text.trim();
    if (roll.isEmpty) return;

    setState(() => _loading = true);

    try {
      final res = await http.post(
        Uri.parse("$BASE_URL/check-roll"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"roll_no": roll}),
      );
      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StudentBiometricScreen(rollNo: roll, studentName: data['name']),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Roll number nahi mila!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Server connect nahi hua: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Verification")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _rollController,
              decoration: const InputDecoration(
                labelText: "Apna Roll Number Dalein",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _verifyRoll,
                      child: const Text("Proceed to Biometric", style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------- STUDENT: BIOMETRIC SCREEN ----------------
class StudentBiometricScreen extends StatefulWidget {
  final String rollNo;
  final String studentName;
  const StudentBiometricScreen({super.key, required this.rollNo, required this.studentName});

  @override
  State<StudentBiometricScreen> createState() => _StudentBiometricScreenState();
}

class _StudentBiometricScreenState extends State<StudentBiometricScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  String _message = "Chehra camera ke samne rakhein";

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await Permission.camera.request();
    CameraDescription selectedCam = cameras.first;
    for (var cam in cameras) {
      if (cam.lensDirection == CameraLensDirection.front) {
        selectedCam = cam;
        break;
      }
    }
    _controller = CameraController(selectedCam, ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _verifyFaceAndMark() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _message = "Face database se match ho raha hai...";
    });

    try {
      final XFile photo = await _controller!.takePicture();
      var request = http.MultipartRequest('POST', Uri.parse("$BASE_URL/verify-attendance"));
      request.fields['roll_no'] = widget.rollNo;
      request.files.add(await http.MultipartFile.fromPath('image', photo.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var result = jsonDecode(response.body);

      setState(() {
        _message = result['message'] ?? "Response received";
      });
    } catch (e) {
      setState(() => _message = "Error: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text("Verify: ${widget.studentName}")),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _isProcessing
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _verifyFaceAndMark,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text("Scan Face & Verify"),
                        ),
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ---------------- TEACHER: DASHBOARD ----------------
class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
              icon: const Icon(Icons.person_add),
              label: const Text("Add New Student (Photo + Details)", style: TextStyle(fontSize: 16)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAddStudentScreen()));
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: Colors.deepPurple,
              ),
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              label: const Text("Attendance Calendar View", style: TextStyle(fontSize: 16, color: Colors.white)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceCalendarScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- TEACHER: ADD STUDENT SCREEN ----------------
class TeacherAddStudentScreen extends StatefulWidget {
  const TeacherAddStudentScreen({super.key});

  @override
  State<TeacherAddStudentScreen> createState() => _TeacherAddStudentScreenState();
}

class _TeacherAddStudentScreenState extends State<TeacherAddStudentScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollController = TextEditingController();
  CameraController? _controller;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    _controller = CameraController(cameras.first, ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _saveStudent() async {
    if (_nameController.text.isEmpty || _rollController.text.isEmpty || _controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saari details bharein!")));
      return;
    }

    setState(() => _loading = true);

    try {
      final photo = await _controller!.takePicture();
      var req = http.MultipartRequest('POST', Uri.parse("$BASE_URL/register"));
      req.fields['name'] = _nameController.text.trim();
      req.fields['roll_no'] = _rollController.text.trim();
      req.files.add(await http.MultipartFile.fromPath('image', photo.path));

      var res = await req.send();
      var response = await http.Response.fromStream(res);
      var json = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(json['message'])));
      if (res.statusCode == 200) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Student")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Student Name")),
            TextField(controller: _rollController, decoration: const InputDecoration(labelText: "Roll Number")),
            const SizedBox(height: 16),
            _controller != null && _controller!.value.isInitialized
                ? SizedBox(height: 250, child: CameraPreview(_controller!))
                : const CircularProgressIndicator(),
            const SizedBox(height: 16),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _saveStudent, child: const Text("Capture Photo & Register")),
          ],
        ),
      ),
    );
  }
}

// ---------------- TEACHER: CALENDAR VIEW ----------------
class AttendanceCalendarScreen extends StatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  State<AttendanceCalendarScreen> createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _attendanceList = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceForDate(_selectedDate);
  }

  Future<void> _fetchAttendanceForDate(DateTime date) async {
    setState(() => _loading = true);
    String formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    try {
      final res = await http.get(Uri.parse("$BASE_URL/get-attendance-by-date?date=$formattedDate"));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() => _attendanceList = data['data']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Data fetch nahi hua: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance Calendar")),
      body: Column(
        children: [
          CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime(2025),
            lastDate: DateTime(2030),
            onDateChanged: (newDate) {
              setState(() => _selectedDate = newDate);
              _fetchAttendanceForDate(newDate);
            },
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _attendanceList.isEmpty
                    ? const Center(child: Text("Is din ka koi record nahi hai"))
                    : ListView.builder(
                        itemCount: _attendanceList.length,
                        itemBuilder: (ctx, i) {
                          final item = _attendanceList[i];
                          bool isPresent = item['status'] == 'PRESENT';
                          return ListTile(
                            leading: Icon(
                              isPresent ? Icons.check_circle : Icons.cancel,
                              color: isPresent ? Colors.green : Colors.red,
                            ),
                            title: Text("${item['name']} (Roll: ${item['roll_no']})"),
                            subtitle: Text("Time: ${item['time']}"),
                            trailing: Text(
                              item['status'],
                              style: TextStyle(
                                color: isPresent ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}