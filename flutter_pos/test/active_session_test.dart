import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:commune_pos/models/staff_user.dart';
import 'package:commune_pos/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('active account profile persists without its password until logout', () async {
    final storage = LocalStorageService();
    await storage.init();

    expect(storage.getActiveStaffId(), isNull);

    await storage.saveActiveStaffSession(
      const StaffUser(
        id: 'staff-123',
        username: 'ray',
        password: 'secret',
        name: 'Ray',
        role: 'cashier',
      ),
    );
    expect(storage.getActiveStaffId(), 'staff-123');
    expect(storage.getActiveStaffProfile()?.name, 'Ray');
    expect(storage.getActiveStaffProfile()?.password, isEmpty);

    await storage.clearActiveStaffId();
    expect(storage.getActiveStaffId(), isNull);
    expect(storage.getActiveStaffProfile(), isNull);
  });
}
