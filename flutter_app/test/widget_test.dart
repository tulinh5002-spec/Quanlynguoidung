import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_management_app/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows login and registration forms', (tester) async {
    await tester.pumpWidget(const UserManagementApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);

    await tester.tap(find.text('Tạo tài khoản').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Tham gia NovaID'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
  });

  testWidgets('opens the input keyboard for every authentication field', (
    tester,
  ) async {
    await tester.pumpWidget(const UserManagementApp());
    await tester.pumpAndSettle();

    Future<void> expectKeyboardForFields(int count) async {
      for (var index = 0; index < count; index++) {
        final field = find.byType(TextFormField).at(index);
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);
        tester.testTextInput.hide();
        await tester.pump();
      }
    }

    await expectKeyboardForFields(2);
    await tester.tap(find.text('Tạo tài khoản').first);
    await tester.pumpAndSettle();
    await expectKeyboardForFields(3);
  });
}
