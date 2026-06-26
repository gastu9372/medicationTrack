import 'dart:convert';
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
  List<Map<String, dynamic>> _allMedicines = [];
  bool _permissionsGranted = false;
  bool _isLoading = true;

  final List<String> _weekDaysShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

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
    final medicines = await _controller.getAllMedicines();
    setState(() {
      _todayTimeline = timeline;
      _allMedicines = medicines;
      _isLoading = false;
    });
  }

  // --- Parse days to readable string ---
  String _getReadableSchedule(String scheduleType, String? scheduleValue) {
    if (scheduleType == 'daily') {
      return "Todos los días";
    }
    try {
      if (scheduleValue == null) return "Días específicos";
      final data = jsonDecode(scheduleValue);
      final List<dynamic> daysList = data['days'] ?? [];
      if (daysList.isEmpty) return "Sin días seleccionados";
      
      final daysNames = daysList.map((dayInt) {
        int idx = (dayInt as int) - 1;
        if (idx >= 0 && idx < _weekDaysShort.length) {
          return _weekDaysShort[idx];
        }
        return '';
      }).where((name) => name.isNotEmpty).join(', ');

      return daysNames;
    } catch (_) {
      return "Días específicos";
    }
  }

  // --- Show Add Medication Dialog ---
  void _showAddMedDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    String scheduleType = 'daily';
    List<int> selectedDays = []; // 1 = Mon, 7 = Sun

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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

                      // Time Selector (Native Time Picker)
                      GestureDetector(
                        onTap: () async {
                          final TimeOfDay? time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFF6366F1),
                                    onPrimary: Colors.white,
                                    surface: Color(0xFF1E1B4B),
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedTime = time;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Color(0xFF818CF8)),
                              const SizedBox(width: 12),
                              Text(
                                "Hora: ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Frequency Dropdown Selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: scheduleType,
                            dropdownColor: const Color(0xFF1E1B4B),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF818CF8)),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'daily', child: Text("Todos los días")),
                              DropdownMenuItem(value: 'days_of_week', child: Text("Días específicos")),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  scheduleType = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Day Selector Chips (only visible if scheduleType == 'days_of_week')
                      if (scheduleType == 'days_of_week') ...[
                        const Text(
                          "Seleccionar días:",
                          style: TextStyle(color: Color(0xFF818CF8), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (index) {
                            final dayNumber = index + 1; // 1 = Mon, 7 = Sun
                            final dayLabel = _weekDaysShort[index].substring(0, 1);
                            final isSelected = selectedDays.contains(dayNumber);

                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedDays.remove(dayNumber);
                                  } else {
                                    selectedDays.add(dayNumber);
                                  }
                                });
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF818CF8) : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  dayLabel,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 12),

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
                                final timeStr = "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";
                                
                                await _controller.addMedicine(
                                  name: nameController.text,
                                  dosage: dosageController.text,
                                  scheduleType: scheduleType,
                                  scheduleTimes: [timeStr],
                                  selectedDays: scheduleType == 'days_of_week' ? selectedDays : null,
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
      },
    );
  }

  // --- Calculate Compliance Stats ---
  // Exclude 'snoozed' logs from total denominator so that only final outcomes affect rate
  double _calculateComplianceRate() {
    final activeToday = _todayTimeline.where((item) => item['status'] != 'snoozed').toList();
    if (activeToday.isEmpty) return 0.0;
    int takenCount = activeToday.where((item) => item['status'] == 'taken').length;
    return takenCount / activeToday.length;
  }

  @override
  Widget build(BuildContext context) {
    // Math logic based on excluding 'snoozed' to keep denominator clean
    final activeToday = _todayTimeline.where((item) => item['status'] != 'snoozed').toList();
    int total = activeToday.length;
    int taken = activeToday.where((item) => item['status'] == 'taken').length;
    double compliance = _calculateComplianceRate();

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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
                            // Circular Progress Ring
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

                      // Section Title: Timeline
                      const Text(
                        "Línea de Tiempo",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Timeline List (ShrinkWrapped inside ScrollView)
                      _todayTimeline.isEmpty
                          ? Container(
                              height: 120,
                              alignment: Alignment.center,
                              child: Text(
                                "No hay medicamentos programados para hoy.",
                                style: TextStyle(color: Colors.white.withOpacity(0.4)),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _todayTimeline.length,
                              itemBuilder: (context, index) {
                                final item = _todayTimeline[index];
                                final time = DateTime.fromMillisecondsSinceEpoch(item['scheduled_time']);
                                final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                                final status = item['status'] as String;

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
                                      Text(
                                        timeStr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        width: 3,
                                        height: 40,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 16),
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

                      const SizedBox(height: 28),

                      // Section Title: My Medications (CRUD Listing)
                      const Text(
                        "Mis Medicamentos",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 12),

                      // Medications Listing (CRUD display & Delete action)
                      _allMedicines.isEmpty
                          ? Container(
                              height: 100,
                              alignment: Alignment.center,
                              child: Text(
                                "No tienes medicamentos registrados.",
                                style: TextStyle(color: Colors.white.withOpacity(0.4)),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _allMedicines.length,
                              itemBuilder: (context, index) {
                                final med = _allMedicines[index];
                                final scheduleType = med['schedule_type'] as String;
                                final scheduleValue = med['schedule_value'] as String?;
                                final scheduleDesc = _getReadableSchedule(scheduleType, scheduleValue);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1B4B).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF312E81).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.medical_services_outlined, color: Color(0xFF818CF8), size: 28),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              med['name'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              med['dosage'] ?? '',
                                              style: const TextStyle(
                                                color: Color(0xFFC7D2FE),
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Frecuencia: $scheduleDesc",
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: const Color(0xFF1E1B4B),
                                              title: const Text("Eliminar Medicamento", style: TextStyle(color: Colors.white)),
                                              content: const Text(
                                                "¿Estás seguro de que deseas eliminar este medicamento y todos sus recordatorios?",
                                                style: TextStyle(color: Color(0xFFC7D2FE)),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text("Cancelar", style: TextStyle(color: Color(0xFF94A3B8))),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text("Eliminar", style: TextStyle(color: Color(0xFFEF4444))),
                                                ),
                                              ],
                                            ),
                                          );
                                          
                                          if (confirm == true) {
                                            await _controller.deleteMedicine(med['id']);
                                            _loadTimeline();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 80), // extra padding for scrolling past FAB
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
