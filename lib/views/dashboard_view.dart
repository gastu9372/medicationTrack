import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/meds_controller.dart';
import '../main.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final MedsController _controller = MedsController();
  List<Map<String, dynamic>> _todayTimeline = [];
  List<Map<String, dynamic>> _allMedicines = [];
  Map<int, double> _weeklyCompliance = {}; // 1 = Mon, 7 = Sun
  bool _permissionsGranted = false;
  Map<String, bool> _permissionsDetail = {
    'notification': false,
    'overlay': false,
    'exactAlarm': false,
  };
  bool _isLoading = true;

  bool _useAlarmSound = true;
  String _customAlarmUri = '';
  String _customAlarmTitle = 'Tono predeterminado';

  final List<String> _weekDaysShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }

  Future<void> _checkPermissionsAndLoad() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _useAlarmSound = prefs.getBool('use_alarm_sound') ?? true;
        _customAlarmUri = prefs.getString('custom_alarm_uri') ?? '';
        _customAlarmTitle = prefs.getString('custom_alarm_title') ?? 'Tono predeterminado';
      });
    } catch (e) {
      debugPrint("Error loading alarm preferences: $e");
    }

    await _controller.checkAndRequestPermissions();
    final detail = await _controller.checkPermissionsDetail();
    final granted = detail.values.every((v) => v);
    setState(() {
      _permissionsGranted = granted;
      _permissionsDetail = detail;
    });

    // Run safety net to ensure all active medications have future scheduled alarms
    await _controller.checkAndRescheduleAlarms();

    await _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    final timeline = await _controller.getTodayTimeline();
    final medicines = await _controller.getAllMedicines();
    final compliance = await _controller.getWeeklyCompliance();
    setState(() {
      _todayTimeline = timeline;
      _allMedicines = medicines;
      _weeklyCompliance = compliance;
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
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
            final labelColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
            final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final chipBgSelected = const Color(0xFF6366F1);
            final chipBgUnselected = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
            final chipTextColorUnselected = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Agregar Recordatorio",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Name Field
                      TextField(
                        controller: nameController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: "Nombre del Medicamento",
                          labelStyle: TextStyle(color: labelColor),
                          filled: true,
                          fillColor: inputBg,
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
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: "Dosis (ej. 500mg, 1 comprimido)",
                          labelStyle: TextStyle(color: labelColor),
                          filled: true,
                          fillColor: inputBg,
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
                                  colorScheme: isDark
                                      ? const ColorScheme.dark(
                                          primary: Color(0xFF6366F1),
                                          onPrimary: Colors.white,
                                          surface: Color(0xFF1E1B4B),
                                          onSurface: Colors.white,
                                        )
                                      : const ColorScheme.light(
                                          primary: Color(0xFF6366F1),
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Color(0xFF0F172A),
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
                            color: inputBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: labelColor),
                              const SizedBox(width: 12),
                              Text(
                                "Hora: ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(color: textColor, fontSize: 16),
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
                          color: inputBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: scheduleType,
                            dropdownColor: dialogBg,
                            style: TextStyle(color: textColor, fontSize: 16),
                            icon: Icon(Icons.keyboard_arrow_down, color: labelColor),
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
                        Text(
                          "Seleccionar días:",
                          style: TextStyle(color: labelColor, fontSize: 14, fontWeight: FontWeight.bold),
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
                                  color: isSelected ? chipBgSelected : chipBgUnselected,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? labelColor : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  dayLabel,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : chipTextColorUnselected,
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
                            child: Text(
                              "Cancelar",
                              style: TextStyle(color: subTextColor),
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

  // --- Show Edit Medication Dialog ---
  void _showEditMedDialog(Map<String, dynamic> med) {
    final nameController = TextEditingController(text: med['name']);
    final dosageController = TextEditingController(text: med['dosage']);
    
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    String scheduleType = med['schedule_type'] ?? 'daily';
    List<int> selectedDays = []; // 1 = Mon, 7 = Sun

    try {
      final value = jsonDecode(med['schedule_value'] ?? '{}');
      final List<dynamic> days = value['days'] ?? [];
      selectedDays = days.map((e) => e as int).toList();
      
      final List<dynamic> times = value['times'] ?? [];
      if (times.isNotEmpty) {
        final parts = (times.first as String).split(':');
        selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
            final labelColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
            final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final chipBgSelected = const Color(0xFF6366F1);
            final chipBgUnselected = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
            final chipTextColorUnselected = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Editar Recordatorio",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                                  title: Text("Eliminar Medicamento", style: TextStyle(color: textColor)),
                                  content: Text(
                                    "¿Estás seguro de que deseas eliminar este medicamento y todos sus recordatorios?",
                                    style: TextStyle(color: subTextColor),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text("Cancelar", style: TextStyle(color: subTextColor)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text("Eliminar", style: TextStyle(color: Color(0xFFEF4444))),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                Navigator.pop(context); // Close edit dialog
                                await _controller.deleteMedicine(med['id']);
                                _loadTimeline();
                              }
                            },
                            tooltip: "Eliminar medicamento",
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Name Field
                      TextField(
                        controller: nameController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: "Nombre del Medicamento",
                          labelStyle: TextStyle(color: labelColor),
                          filled: true,
                          fillColor: inputBg,
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
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: "Dosis (ej. 500mg, 1 comprimido)",
                          labelStyle: TextStyle(color: labelColor),
                          filled: true,
                          fillColor: inputBg,
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
                                  colorScheme: isDark
                                      ? const ColorScheme.dark(
                                          primary: Color(0xFF6366F1),
                                          onPrimary: Colors.white,
                                          surface: Color(0xFF1E1B4B),
                                          onSurface: Colors.white,
                                        )
                                      : const ColorScheme.light(
                                          primary: Color(0xFF6366F1),
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Color(0xFF0F172A),
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
                            color: inputBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: labelColor),
                              const SizedBox(width: 12),
                              Text(
                                "Hora: ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(color: textColor, fontSize: 16),
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
                          color: inputBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: scheduleType,
                            dropdownColor: dialogBg,
                            style: TextStyle(color: textColor, fontSize: 16),
                            icon: Icon(Icons.keyboard_arrow_down, color: labelColor),
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
                        Text(
                          "Seleccionar días:",
                          style: TextStyle(color: labelColor, fontSize: 14, fontWeight: FontWeight.bold),
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
                                  color: isSelected ? chipBgSelected : chipBgUnselected,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? labelColor : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  dayLabel,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : chipTextColorUnselected,
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
                            child: Text(
                              "Cancelar",
                              style: TextStyle(color: subTextColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.isNotEmpty && dosageController.text.isNotEmpty) {
                                final timeStr = "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";
                                
                                await _controller.updateMedicine(
                                  id: med['id'],
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
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
  double _calculateComplianceRate() {
    final activeToday = _todayTimeline.where((item) => item['status'] != 'snoozed').toList();
    if (activeToday.isEmpty) return 0.0;
    int takenCount = activeToday.where((item) => item['status'] == 'taken').length;
    return takenCount / activeToday.length;
  }

  // --- Weekly Progress Widget with Letter Circles ---
  Widget _buildWeeklyProgressRow(bool isDark) {
    final progressCardTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final progressCircleBg = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.05);
    final progressCircleBorder = isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.12);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final dayNumber = index + 1; // 1 = Mon, 7 = Sun
        final dayLabel = _weekDaysShort[index].substring(0, 1);
        final rate = _weeklyCompliance[dayNumber] ?? -1.0;
        final hasAlarms = rate >= 0.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: hasAlarms
                  ? CircularProgressIndicator(
                      value: rate,
                      strokeWidth: 3.5,
                      backgroundColor: progressCircleBg,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: progressCircleBorder,
                          width: 1.5,
                        ),
                      ),
                    ),
            ),
            Text(
              dayLabel,
              style: TextStyle(
                color: progressCardTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _updateAlarmSoundSetting(bool value, StateSetter setBottomSheetState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_alarm_sound', value);
      setBottomSheetState(() {
        _useAlarmSound = value;
      });
      setState(() {
        _useAlarmSound = value;
      });
    } catch (e) {
      debugPrint("Error updating alarm sound setting: $e");
    }
  }

  Future<void> _pickAndSaveRingtone(StateSetter setBottomSheetState) async {
    const platform = MethodChannel('com.example.medstracker/alarms');
    try {
      final result = await platform.invokeMethod('pickRingtone', {
        'currentUri': _customAlarmUri,
      });
      if (result != null) {
        final map = Map<String, dynamic>.from(result);
        final uri = map['uri'] as String;
        final title = map['title'] as String;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('custom_alarm_uri', uri);
        await prefs.setString('custom_alarm_title', title);

        setBottomSheetState(() {
          _customAlarmUri = uri;
          _customAlarmTitle = title;
        });
        setState(() {
          _customAlarmUri = uri;
          _customAlarmTitle = title;
        });
      }
    } catch (e) {
      debugPrint("Error picking ringtone: $e");
    }
  }

  // --- Show Settings Bottom Sheet with Theme Mode and Permissions Settings ---
  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
            final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

            return ValueListenableBuilder<ThemeMode>(
              valueListenable: MedsTrackerApp.themeNotifier,
              builder: (context, currentMode, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pull handler
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(Icons.settings, color: titleColor, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            "Configuración",
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Section 1: Theme Mode Selection
                      Text(
                        "Tema de la Aplicación",
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildThemeOption(
                            context: context,
                            mode: ThemeMode.system,
                            label: "Sistema",
                            icon: Icons.brightness_auto,
                            currentMode: currentMode,
                            isDark: isDark,
                            cardBg: cardBg,
                          ),
                          const SizedBox(width: 8),
                          _buildThemeOption(
                            context: context,
                            mode: ThemeMode.light,
                            label: "Claro",
                            icon: Icons.light_mode,
                            currentMode: currentMode,
                            isDark: isDark,
                            cardBg: cardBg,
                          ),
                          const SizedBox(width: 8),
                          _buildThemeOption(
                            context: context,
                            mode: ThemeMode.dark,
                            label: "Oscuro",
                            icon: Icons.dark_mode,
                            currentMode: currentMode,
                            isDark: isDark,
                            cardBg: cardBg,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section: Alert settings
                      Text(
                        "Configuración de Alertas",
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Ruido tipo alarma",
                                        style: TextStyle(
                                          color: titleColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Sonido continuo y vibración persistente al alertar",
                                        style: TextStyle(
                                          color: subTextColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _useAlarmSound,
                                  activeColor: const Color(0xFF6366F1),
                                  onChanged: (val) => _updateAlarmSoundSetting(val, setBottomSheetState),
                                ),
                              ],
                            ),
                            if (_useAlarmSound) ...[
                              const Divider(height: 20, thickness: 1),
                              InkWell(
                                onTap: () => _pickAndSaveRingtone(setBottomSheetState),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Sonido de la alarma",
                                              style: TextStyle(
                                                color: titleColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _customAlarmTitle.isEmpty ? "Tono predeterminado" : _customAlarmTitle,
                                              style: const TextStyle(
                                                color: Color(0xFF6366F1),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Color(0xFF6366F1)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Section 2: Permissions Diagnostic
                      Text(
                        "Permisos de Sistema",
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildPermissionItem(
                              icon: Icons.notifications_active_outlined,
                              label: "Notificaciones",
                              desc: "Necesario para alertas en barra de estado",
                              isGranted: _permissionsDetail['notification'] ?? false,
                              isDark: isDark,
                            ),
                            const Divider(height: 12, thickness: 1),
                            _buildPermissionItem(
                              icon: Icons.layers_outlined,
                              label: "Mostrar sobre otras apps",
                              desc: "Necesario para la pantalla de alarma bloqueada",
                              isGranted: _permissionsDetail['overlay'] ?? false,
                              isDark: isDark,
                            ),
                            const Divider(height: 12, thickness: 1),
                            _buildPermissionItem(
                              icon: Icons.alarm,
                              label: "Alarmas exactas",
                              desc: "Requerido para activar alertas al segundo exacto",
                              isGranted: _permissionsDetail['exactAlarm'] ?? false,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _controller.checkAndRequestPermissions();
                            final detail = await _controller.checkPermissionsDetail();
                            final granted = detail.values.every((v) => v);
                            
                            // Update both bottom sheet state and main widget state
                            setBottomSheetState(() {
                              _permissionsGranted = granted;
                              _permissionsDetail = detail;
                            });
                            setState(() {
                              _permissionsGranted = granted;
                              _permissionsDetail = detail;
                            });
                            
                            // Reload timeline
                            final timeline = await _controller.getTodayTimeline();
                            final medicines = await _controller.getAllMedicines();
                            final compliance = await _controller.getWeeklyCompliance();
                            setState(() {
                              _todayTimeline = timeline;
                              _allMedicines = medicines;
                              _weeklyCompliance = compliance;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Recomprobar y Otorgar Permisos",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required ThemeMode mode,
    required String label,
    required IconData icon,
    required ThemeMode currentMode,
    required bool isDark,
    required Color cardBg,
  }) {
    final isSelected = currentMode == mode;
    final activeColor = const Color(0xFF6366F1);
    final borderColor = isSelected 
        ? activeColor 
        : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08));

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          MedsTrackerApp.themeNotifier.value = mode;
          final prefs = await SharedPreferences.getInstance();
          int themeIndex = 0; // system
          if (mode == ThemeMode.light) themeIndex = 1;
          if (mode == ThemeMode.dark) themeIndex = 2;
          await prefs.setInt('theme_mode', themeIndex);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.15) : cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? activeColor 
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String label,
    required String desc,
    required bool isGranted,
    required bool isDark,
  }) {
    final statusColor = isGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final statusText = isGranted ? "Permitido" : "Requerido";
    final labelColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final descColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final statusBg = statusColor.withOpacity(0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: descColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Dynamic theme colors
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBgColor = isDark ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.white;
    final cardBorderColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.06);

    // Compliance logic calculations
    final activeToday = _todayTimeline.where((item) => item['status'] != 'snoozed').toList();
    int total = activeToday.length;
    int taken = activeToday.where((item) => item['status'] == 'taken').length;
    double compliance = _calculateComplianceRate();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
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
                              Text(
                                "Medicinas de Hoy",
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateTime.now().toLocal().toString().substring(0, 10),
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.settings, color: primaryTextColor),
                            onPressed: _showSettingsBottomSheet,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),

                      // Compliance Progress Card (Vibrant Indigo Gradient in both modes)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: isDark 
                              ? const LinearGradient(
                                  colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isDark ? null : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: isDark 
                              ? null 
                              : Border.all(color: Colors.black.withOpacity(0.06)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Progreso",
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // Big percent summary badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    total == 0 ? "0%" : "${(compliance * 100).toInt()}%",
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            
                            // Row of Weekdays Circles right below the title as in the sketch
                            _buildWeeklyProgressRow(isDark),
                            
                            const SizedBox(height: 18),
                            Divider(color: isDark ? Colors.white24 : Colors.black.withOpacity(0.08), height: 1),
                            const SizedBox(height: 14),
                            
                            // Summary text below the divider
                            Row(
                              children: [
                                Icon(
                                  total == 0 
                                      ? Icons.info_outline 
                                      : (compliance == 1.0 ? Icons.check_circle_outline : Icons.pending_actions),
                                  color: total == 0 
                                      ? (isDark ? const Color(0xFFC7D2FE) : const Color(0xFF64748B))
                                      : (compliance == 1.0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    total == 0
                                        ? "Sin medicamentos programados para hoy"
                                        : "Has tomado $taken de $total medicamentos.",
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF475569),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section Title: Timeline
                      Text(
                        "Línea de Tiempo",
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Timeline List
                      activeToday.isEmpty
                          ? Container(
                              height: 100,
                              alignment: Alignment.center,
                              child: Text(
                                "No hay medicamentos programados para hoy.",
                                style: TextStyle(color: subTextColor.withOpacity(0.7)),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activeToday.length,
                              itemBuilder: (context, index) {
                                final item = activeToday[index];
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

                                final isCompleted = status != 'pending';
                                final cardPadding = isCompleted 
                                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
                                
                                final double activeOpacity = isCompleted ? 0.6 : 1.0;
                                final titleSize = isCompleted ? 15.0 : 18.0;
                                final subtitleSize = isCompleted ? 12.0 : 13.0;
                                final indicatorHeight = isCompleted ? 26.0 : 38.0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: cardPadding,
                                  decoration: BoxDecoration(
                                    color: cardBgColor.withOpacity(isCompleted ? (isDark ? 0.35 : 0.65) : (isDark ? 0.5 : 1.0)),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cardBorderColor.withOpacity(isCompleted ? 0.5 : 1.0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Colored status indicator vertical pill
                                      Container(
                                        width: 5,
                                        height: indicatorHeight,
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(activeOpacity),
                                          borderRadius: BorderRadius.circular(2.5),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'] ?? '',
                                              style: TextStyle(
                                                color: primaryTextColor.withOpacity(activeOpacity),
                                                fontSize: titleSize,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "hora: $timeStr${item['dosage'] != null && (item['dosage'] as String).isNotEmpty ? ' • ${item['dosage']}' : ''}",
                                              style: TextStyle(
                                                color: subTextColor.withOpacity(activeOpacity),
                                                fontSize: subtitleSize,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (status == 'pending')
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Checkmark button (taken)
                                            IconButton(
                                              icon: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 26),
                                              onPressed: () async {
                                                await _controller.markTaken(
                                                  item['id'],
                                                  item['medicine_id'],
                                                  item['scheduled_time'],
                                                );
                                                _loadTimeline();
                                              },
                                              tooltip: "Tomar",
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(8),
                                            ),
                                            // Alarm clock button (snooze)
                                            IconButton(
                                              icon: const Icon(Icons.alarm, color: Color(0xFFF59E0B), size: 26),
                                              onPressed: () async {
                                                await _controller.markSnoozed(
                                                  item['id'],
                                                  item['medicine_id'],
                                                  item['scheduled_time'],
                                                );
                                                _loadTimeline();
                                              },
                                              tooltip: "Posponer",
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(8),
                                            ),
                                            // X button (missed)
                                            IconButton(
                                              icon: const Icon(Icons.close, color: Color(0xFFEF4444), size: 26),
                                              onPressed: () async {
                                                await _controller.markMissed(
                                                  item['id'],
                                                  item['medicine_id'],
                                                  item['scheduled_time'],
                                                );
                                                _loadTimeline();
                                              },
                                              tooltip: "Perder",
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(8),
                                            ),
                                          ],
                                        )
                                      else
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: statusColor.withOpacity(0.2)),
                                              ),
                                              child: Text(
                                                statusLabel,
                                                style: TextStyle(
                                                  color: statusColor.withOpacity(0.8),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (status == 'missed') ...[
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 26),
                                                onPressed: () async {
                                                  await _controller.markTaken(
                                                    item['id'],
                                                    item['medicine_id'],
                                                    item['scheduled_time'],
                                                  );
                                                  _loadTimeline();
                                                },
                                                tooltip: "Tomar tarde",
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(4),
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),

                      const SizedBox(height: 28),

                      // Section Title: My Medications
                      Text(
                        "Mis Medicamentos",
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 12),

                      // Medications list
                      _allMedicines.isEmpty
                          ? Container(
                              height: 80,
                              alignment: Alignment.center,
                              child: Text(
                                "No tienes medicamentos registrados.",
                                style: TextStyle(color: subTextColor.withOpacity(0.7)),
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

                                return GestureDetector(
                                  onTap: () => _showEditMedDialog(med),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: cardBorderColor,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.medical_services_outlined, color: Color(0xFF6366F1), size: 28),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                med['name'] ?? '',
                                                style: TextStyle(
                                                  color: primaryTextColor,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                med['dosage'] ?? '',
                                                style: TextStyle(
                                                  color: subTextColor,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "Frecuencia: $scheduleDesc",
                                                style: TextStyle(
                                                  color: subTextColor.withOpacity(0.8),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: subTextColor.withOpacity(0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 80), // spacer for FAB
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
