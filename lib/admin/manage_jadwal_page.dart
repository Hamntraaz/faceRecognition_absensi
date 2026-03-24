import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManageJadwalPage extends StatefulWidget {
  final String userId;
  final String userName;

  const ManageJadwalPage({super.key, required this.userId, required this.userName});

  @override
  State<ManageJadwalPage> createState() => _ManageJadwalPageState();
}

class _ManageJadwalPageState extends State<ManageJadwalPage> {
  final List<String> _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  // Konfigurasi Jam Default
  final Map<String, Map<String, String>> _defaultTimes = {
    'Pagi': {'in': '08:00', 'out': '17:00'},
    'Siang': {'in': '11:00', 'out': '20:00'},
    'Sore': {'in': '14:00', 'out': '22:00'},
    'Malam': {'in': '22:00', 'out': '07:00'},
    'Custom': {'in': '00:00', 'out': '00:00'},
  };

  // State Management
  Map<String, Map<String, dynamic>> _scheduleData = {};
  Map<String, TextEditingController> _inControllers = {};
  Map<String, TextEditingController> _outControllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _prepareControllers();
    _fetchDataFromFirestore();
  }

  void _prepareControllers() {
    for (var day in _days) {
      _inControllers[day] = TextEditingController(text: '08:00');
      _outControllers[day] = TextEditingController(text: '17:00');
      _scheduleData[day] = {
        'shift': 'Pagi',
        'is_off': false,
      };
    }
  }

  Future<void> _fetchDataFromFirestore() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('all_schedules')
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          for (var doc in snapshot.docs) {
            String day = doc.id;
            var data = doc.data();
            _scheduleData[day] = {
              'shift': data['shift'] ?? 'Pagi',
              'is_off': data['is_off'] ?? false,
            };
            _inControllers[day]!.text = data['time_in'] ?? '08:00';
            _outControllers[day]!.text = data['time_out'] ?? '17:00';
          }
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateShift(String day, String shift) {
    setState(() {
      _scheduleData[day]!['shift'] = shift;
      if (shift != 'Custom') {
        _inControllers[day]!.text = _defaultTimes[shift]!['in']!;
        _outControllers[day]!.text = _defaultTimes[shift]!['out']!;
      }
    });
  }

  void _copyMondayToAll() {
    String sourceIn = _inControllers['Senin']!.text;
    String sourceOut = _outControllers['Senin']!.text;
    String sourceShift = _scheduleData['Senin']!['shift'];
    bool sourceOff = _scheduleData['Senin']!['is_off'];

    setState(() {
      for (var day in _days) {
        _inControllers[day]!.text = sourceIn;
        _outControllers[day]!.text = sourceOut;
        _scheduleData[day]!['shift'] = sourceShift;
        _scheduleData[day]!['is_off'] = sourceOff;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jadwal Senin disalin ke semua hari")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Jadwal: ${widget.userName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.copy_all), onPressed: _copyMondayToAll),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _days.length,
              itemBuilder: (context, index) => _buildDayCard(_days[index]),
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildDayCard(String day) {
    bool isOff = _scheduleData[day]!['is_off'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOff ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isOff ? Colors.transparent : Colors.blue.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  const Text("Libur", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Switch(
                    value: isOff,
                    onChanged: (v) => setState(() => _scheduleData[day]!['is_off'] = v),
                  ),
                ],
              )
            ],
          ),
          if (!isOff) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _scheduleData[day]!['shift'],
                    items: ['Pagi', 'Siang', 'Sore', 'Malam', 'Custom']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => _updateShift(day, v!),
                    decoration: const InputDecoration(labelText: "Shift", border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildTimeInput(day, _inControllers[day]!, "Masuk")),
                const SizedBox(width: 8),
                Expanded(child: _buildTimeInput(day, _outControllers[day]!, "Pulang")),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildTimeInput(String day, TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [_TimeMaskFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: "00:00",
        labelStyle: const TextStyle(fontSize: 11),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _saveData,
        child: const Text("SIMPAN JADWAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _saveData() async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var day in _days) {
        var ref = FirebaseFirestore.instance
            .collection('users').doc(widget.userId)
            .collection('all_schedules').doc(day);

        batch.set(ref, {
          'shift': _scheduleData[day]!['shift'],
          'time_in': _inControllers[day]!.text,
          'time_out': _outControllers[day]!.text,
          'is_off': _scheduleData[day]!['is_off'],
        });
      }
      await batch.commit();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Jadwal tersimpan!")));
    } catch (e) {
      Navigator.pop(context);
      print(e);
    }
  }

  @override
  void dispose() {
    _inControllers.values.forEach((c) => c.dispose());
    _outControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
}

class _TimeMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(':', '');
    if (text.length > 4) return oldValue;
    String newText = text;
    if (text.length > 2) newText = '${text.substring(0, 2)}:${text.substring(2)}';
    return TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}