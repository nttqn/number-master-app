import 'package:shared_preferences/shared_preferences.dart';

/// Persists progress across app restarts: highest unlocked level and the
/// best (largest) final number reached per level.
class SaveService {
  SaveService._();
  static final SaveService instance = SaveService._();

  static const _unlockedLevelKey = 'nm_unlocked_level';
  static const _bestNumberPrefix = 'nm_best_number_';

  Future<int> getUnlockedLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_unlockedLevelKey) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  Future<void> unlockLevel(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_unlockedLevelKey) ?? 1;
      if (level > current) {
        await prefs.setInt(_unlockedLevelKey, level);
      }
    } catch (_) {}
  }

  Future<int> getBestNumber(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_bestNumberPrefix$level') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> recordBestNumber(int level, int finalNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_bestNumberPrefix$level';
      final current = prefs.getInt(key) ?? 0;
      if (finalNumber > current) {
        await prefs.setInt(key, finalNumber);
      }
    } catch (_) {}
  }
}
