import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/ads_service.dart';
import 'services/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdsService.instance.initialize();
  // Deliberately not awaited: a missing/invalid audio asset can leave the
  // underlying platform Future hanging (rather than rejecting) on some
  // browsers, which would otherwise block the whole app from ever
  // rendering. Sound finishes loading in the background whenever it does;
  // SoundService.play() no-ops safely until then.
  unawaited(SoundService.instance.init());
  runApp(const NumberMasterApp());
}
