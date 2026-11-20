import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bankos_project/core/theme/app_theme.dart';
import 'package:bankos_project/features/auth/presentation/screens/login_screen.dart';
import 'package:bankos_project/features/auth/data/repositories/auth_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO', null);
  });

  testWidgets('LoginScreen renderiza campos de inicio de sesión', (WidgetTester tester) async {
    final mockAuth = MockAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: LoginScreen(repository: mockAuth),
      ),
    );

    expect(find.text('BankOS'), findsOneWidget);
    expect(find.text('Experiencia de Bancolombia · BankOS'), findsOneWidget);
    expect(find.text('Institución Financiera (Tenant)'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });

  testWidgets('Valida campos vacíos antes de enviar', (WidgetTester tester) async {
    final mockAuth = MockAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: LoginScreen(repository: mockAuth),
      ),
    );

    // Limpiar campos
    final emailField = find.byType(TextFormField).first;
    await tester.enterText(emailField, '');

    final loginBtn = find.text('Iniciar Sesión');
    await tester.ensureVisible(loginBtn);
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
  });
}
