import 'package:flutter_test/flutter_test.dart';
import 'package:commune_pos/models/staff_user.dart';

void main() {
  test('POS access is cashier-only and shift access is barista-only', () {
    const cashier = StaffUser(
      id: 'cashier-1',
      username: 'cashier',
      password: 'pass',
      name: 'Cashier',
      role: 'cashier',
    );
    const manager = StaffUser(
      id: 'manager-1',
      username: 'manager',
      password: 'pass',
      name: 'Manager',
      role: 'manager',
    );
    const barista = StaffUser(
      id: 'barista-1',
      username: 'barista',
      password: 'pass',
      name: 'Barista',
      role: 'barista',
    );

    expect(cashier.canUsePos, isTrue);
    expect(cashier.canAccessBaristaShift, isFalse);
    expect(manager.canUsePos, isFalse);
    expect(manager.canAccessBaristaShift, isFalse);
    expect(barista.canUsePos, isFalse);
    expect(barista.canAccessBaristaShift, isTrue);
  });
}
