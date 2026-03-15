 Architecture Flutter & Android Natif1. Stack Technique & PluginsFramework : Flutter (Dart) - Cible Android uniquement.Base de données : sqflite (Stockage local persistant).Moteur d'alarmes : android_alarm_manager_plus.Notifications & Overlays : flutter_local_notifications (avec Full Screen Intent).2. Logique de Planification (Le Cœur)Le calcul ne doit pas être relatif, mais absolu :DartDateTime calculateNextOccurrence(int hour, int minute) {
  final now = DateTime.now();
  DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
  
  // Si l'heure est déjà passée aujourd'hui, on prévoit pour demain
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}
3. Gestion de la Résilience (Android Lifecycle)BOOT_COMPLETED : Le plugin android_alarm_manager_plus doit être configuré dans le AndroidManifest.xml pour persister après reboot.Battery Optimization : L'app doit rediriger l'utilisateur vers les paramètres pour être ajoutée à la "Liste blanche" de batterie (indispensable sur les vieux téléphones).Exact Alarm : Utilisation de SCHEDULE_EXACT_ALARM pour éviter que le système ne décale l'heure de sonnerie pour grouper les tâches.4. Tableau de gestion des risques (Anti-Bug)RisqueSolutionLe téléphone redémarrePermission RECEIVE_BOOT_COMPLETED + AlarmManager persistant.L'alarme sonne mais l'app est ferméeUtilisation d'un Isolate (Background process) via android_alarm_manager.Conflit d'ID d'alarmeUtiliser l'ID unique de la ligne SQLite comme alarmID.Mémoire saturéeÉviter les images et les assets lourds. Uniquement du code et des icônes système.