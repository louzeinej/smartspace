import 'package:flutter_test/flutter_test.dart';

import 'package:smartspace/reservations/ui/smartspace_style.dart';

void main() {
  test('formatDate produit yyyy-MM-dd', () {
    expect(formatDate(DateTime(2026, 3, 7)), '2026-03-07');
  });

  test('afficherDate convertit en dd/MM/yyyy', () {
    expect(afficherDate('2026-03-07'), '07/03/2026');
  });
}
