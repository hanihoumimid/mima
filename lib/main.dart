import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'alarm_service.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isAndroid =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  try {
    if (isAndroid) {
      await AndroidAlarmManager.initialize();
    }
    await AlarmService.init();
    // Reschedule all active alarms on every cold start (handles post-boot
    // recovery even without a dedicated BroadcastReceiver on older firmware).
    await AlarmService.rescheduleAll();
  } catch (e, stackTrace) {
    debugPrint('Startup initialization error: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const MamieMedsApp());
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class MamieMedsApp extends StatelessWidget {
  const MamieMedsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mamie-Meds',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1A1A2E),
          onPrimary: Colors.white,
          secondary: Color(0xFFFFD700),
          onSecondary: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 20),
          titleLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Home page
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<Medication> _medications = [];
  bool _loading = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _loadData();
    _maybeRequestBatteryOptimisation();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final meds = await DatabaseHelper.instance.getMedications();
    if (!mounted) return;
    setState(() {
      _medications = meds;
      _loading = false;
    });
    _animController.forward(from: 0);
  }

  // --------------------------------------------------------------------------
  // Battery optimisation
  // --------------------------------------------------------------------------

  Future<void> _maybeRequestBatteryOptimisation() async {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) return;
    // Give the first frame a moment to settle before showing a dialog.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isDenied && mounted) {
      _showBatteryDialog();
    }
  }

  void _showBatteryDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '⚡ Optimisation batterie',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Pour que les alarmes sonnent même quand le téléphone est en veille, '
          'veuillez désactiver l\'optimisation de la batterie pour cette application.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Permission.ignoreBatteryOptimizations.request();
            },
            child: const Text('Autoriser', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // CRUD actions
  // --------------------------------------------------------------------------

  Future<void> _addMedication() async {
    final result = await showDialog<Medication>(
      context: context,
      builder: (ctx) => const _MedicationFormDialog(),
    );
    if (result == null) return;

    final id = await DatabaseHelper.instance.insertMedication(result);
    final saved = result.copyWith(id: id);
    if (saved.isActive) {
      await AlarmService.scheduleAlarm(saved);
    }
    await _loadData();
  }

  Future<void> _toggleActive(Medication med) async {
    final updated = med.copyWith(isActive: !med.isActive);
    await DatabaseHelper.instance.updateMedication(updated);
    if (updated.isActive) {
      await AlarmService.scheduleAlarm(updated);
    } else {
      await AlarmService.cancelAlarm(updated.id!);
    }
    await _loadData();
  }

  Future<void> _deleteMedication(Medication med) async {
    await AlarmService.cancelAlarm(med.id!);
    await DatabaseHelper.instance.deleteMedication(med.id!);
    await _loadData();
  }

  Future<void> _confirmDelete(Medication med) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?', style: TextStyle(fontSize: 22)),
        content: Text(
          'Supprimer "${med.name}" et son alarme ?',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteMedication(med);
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '💊  Mamie-Meds',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: _medications.isEmpty
                  ? _buildEmptyState()
                  : _buildList(),
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: 72,
          child: FloatingActionButton.extended(
            onPressed: _addMedication,
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add, size: 32),
            label: const Text(
              'Ajouter',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.medication, size: 100, color: Color(0xFF1A1A2E)),
            SizedBox(height: 24),
            Text(
              'Aucun médicament',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Appuyez sur « Ajouter » pour créer\nun premier rappel.',
              style: TextStyle(fontSize: 20, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _medications.length,
      itemBuilder: (ctx, i) => _buildCard(_medications[i]),
    );
  }

  Widget _buildCard(Medication med) {
    final timeStr =
        '${med.hour.toString().padLeft(2, '0')}:${med.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: med.isActive ? const Color(0xFF1A1A2E) : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name row
            Row(
              children: [
                Icon(
                  Icons.medication_liquid,
                  size: 40,
                  color: med.isActive ? const Color(0xFF1A1A2E) : Colors.grey,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    med.name,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color:
                          med.isActive ? const Color(0xFF1A1A2E) : Colors.grey,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 32),
                  color: Colors.red.shade400,
                  onPressed: () => _confirmDelete(med),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Time + toggle row
            Row(
              children: [
                const Icon(Icons.access_time, size: 28, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Transform.scale(
                  scale: 1.4,
                  child: Switch(
                    value: med.isActive,
                    onChanged: (_) => _toggleActive(med),
                    activeColor: const Color(0xFFFFD700),
                    activeTrackColor: const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            if (!med.isActive)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Alarme désactivée',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / edit medication dialog
// ---------------------------------------------------------------------------

class _MedicationFormDialog extends StatefulWidget {
  const _MedicationFormDialog();

  @override
  State<_MedicationFormDialog> createState() => _MedicationFormDialogState();
}

class _MedicationFormDialogState extends State<_MedicationFormDialog> {
  final _nameController = TextEditingController();
  int _hour = 8;
  int _minute = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Entrez un nom de médicament.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      Medication(name: name, hour: _hour, minute: _minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: const Text(
        'Nouveau médicament',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 22),
            decoration: const InputDecoration(
              labelText: 'Nom du médicament',
              labelStyle: TextStyle(fontSize: 18),
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.medication, size: 28),
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 72,
            child: OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.access_time, size: 30),
              label: Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1A1A2E), width: 2),
                foregroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(fontSize: 18)),
        ),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A2E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: const Text(
              'Enregistrer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

