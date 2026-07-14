import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/watch_sync_service.dart';

final watchSyncServiceProvider = Provider<WatchSyncService>((ref) {
  final service = WatchSyncService();
  service.init();
  return service;
});
