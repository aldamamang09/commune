import 'package:flutter/material.dart';
import 'services/local_storage_service.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';
import 'state/pos_controller.dart';
import 'ui/theme.dart';
import 'ui/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Local-First persistent storage
  final localStorage = LocalStorageService();
  await localStorage.init();

  // 2. Initialize Centralized Backend & Supabase Client
  final supabaseService = SupabaseService();
  await supabaseService.initialize(
    url: localStorage.getSupabaseUrl(),
    anonKey: localStorage.getSupabaseAnonKey(),
    adminApiUrl: localStorage.getAdminApiUrl(),
  );

  // 3. Initialize Background & Real-Time Auto-Sync Service
  final syncService = SyncService(
    localStorage: localStorage,
    supabaseService: supabaseService,
  );

  // 4. Initialize State Controller (registers sync listener & pulls fresh Admin data)
  final posController = PosController(
    localStorage: localStorage,
    supabaseService: supabaseService,
    syncService: syncService,
  );
  syncService.start();
  await posController.init();

  runApp(CommunePosApp(controller: posController));
}

class CommunePosApp extends StatelessWidget {
  final PosController controller;

  const CommunePosApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Commune Coffee POS',
      debugShowCheckedModeBanner: false,
      theme: CommuneTheme.theme,
      home: LoginScreen(controller: controller),
    );
  }
}
