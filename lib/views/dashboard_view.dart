import 'package:flutter/material.dart';
import '../controllers/meds_controller.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final MedsController _controller = MedsController();
  List<Map<String, dynamic>> _todayTimeline = [];
  bool _permissionsGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }

  Future<void> _checkPermissionsAndLoad() async {
    setState(() => _isLoading = true);
    final granted = await _controller.checkAndRequestPermissions();
    setState(() {
      _permissionsGranted = granted;
    });
    await _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    final timeline = await _controller.getTodayTimeline();
    setState(() {
      _todayTimeline = timeline;
      _isLoading = false;
    });
  }

  // --- Show Add Medication Dialog ---
  void _showAddMedDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final timeController = TextEditingController(text: "08:00");

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Agregar Recordatorio",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Name Field
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Nombre del Medicamento",
                      labelStyle: const TextStyle(color: Color(0xFF818CF8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dosage Field
                  TextField(
                    controller: dosageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Dosis (ej. 500mg, 1 comprimido)",
                      labelStyle: const TextStyle(color: Color(0xFF818CF8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time Selection Field
                  TextField(
                    controller: timeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Hora (Formato HH:mm)",
                      labelStyle: const TextStyle(color: Color(0xFF818CF8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      prefixIcon: const Icon(Icons.access_time, color: Color(0xFF818CF8)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancelar",
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.isNotEmpty && dosageController.text.isNotEmpty) {
                            await _controller.addMedicine(
                              name: nameController.text,
                              dosage: dosageController.text,
                              scheduleType: 'daily',
                              scheduleTimes: [timeController.text],
                            );
                            Navigator.pop(context);
                            _loadTimeline();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text("Guardar", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Calculate Compliance Stats ---
  double _calculateComplianceRate() {
    if (_todayTimeline.isEmpty) return 0.0;
    int takenCount = _todayTimeline.where((item) => item['status'] == 'taken').length;
    return takenCount / _todayTimeline.length;
  }

  @override
  Widget build(BuildContext context) {
    double compliance = _calculateComplianceRate();
    int taken = _todayTimeline.where((item) => item['status'] == 'taken').length;
    int total = _todayTimeline.length;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Header Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Medicinas de Hoy",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateTime.now().toLocal().toString().substring(0, 10),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: _checkPermissionsAndLoad,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                // Compliance Progress Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Circular Progress
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 70,
                            height: 70,
                            child: CircularProgressIndicator(
                              value: total == 0 ? 0.0 : compliance,
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            ),
                          ),
                          Text(
                            total == 0 ? "0%" : "${(compliance * 100).toInt()}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      // Text Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Progreso del Día",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              total == 0
                                  ? "Sin medicamentos programados"
                                  : "Has tomado $taken de $total medicamentos programados.",
                              style: const TextStyle(
                                color: Color(0xFFC7D2FE),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Subtitle
                const Text(
                  "Línea de Tiempo",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Main Timeline List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _todayTimeline.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.medication_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No hay medicamentos programados.",
                                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _todayTimeline.length,
                              itemBuilder: (context, index) {
                                final item = _todayTimeline[index];
                                final time = DateTime.fromMillisecondsSinceEpoch(item['scheduled_time']);
                                final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                                final status = item['status'] as String;

                                // Colors based on status
                                Color statusColor = const Color(0xFF6366F1); // pending
                                String statusLabel = "Pendiente";
                                if (status == 'taken') {
                                  statusColor = const Color(0xFF10B981);
                                  statusLabel = "Tomado";
                                } else if (status == 'snoozed') {
                                  statusColor = const Color(0xFFF59E0B);
                                  statusLabel = "Pospuesto";
                                } else if (status == 'missed') {
                                  statusColor = const Color(0xFFEF4444);
                                  statusLabel = "Perdido";
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.05),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Scheduled Time Left Side
                                      Text(
                                        timeStr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Divider indicator line
                                      Container(
                                        width: 3,
                                        height: 40,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 16),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              item['dosage'] ?? '',
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Status Badge / Actions
                                      if (status == 'pending')
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
                                              onPressed: () async {
                                                await _controller.markTaken(
                                                  item['id'],
                                                  item['medicine_id'],
                                                  item['scheduled_time'],
                                                );
                                                _loadTimeline();
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.snooze, color: Color(0xFFF59E0B)),
                                              onPressed: () async {
                                                await _controller.markSnoozed(
                                                  item['id'],
                                                  item['medicine_id'],
                                                  item['scheduled_time'],
                                                );
                                                _loadTimeline();
                                              },
                                            ),
                                          ],
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: statusColor.withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMedDialog,
        backgroundColor: const Color(0xFF6366F1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
