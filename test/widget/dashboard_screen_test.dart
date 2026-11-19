import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bankos_project/core/theme/app_theme.dart';
import 'package:bankos_project/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:bankos_project/features/dashboard/data/repositories/mock_dashboard_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO', null);
  });

  testWidgets('DashboardScreen carga y muestra cuentas con MockDashboardRepository',
      (WidgetTester tester) async {
    final mockRepo = MockDashboardRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DashboardScreen(repository: mockRepo),
      ),
    );

    // Estado inicial: Loading
    expect(find.text('Cargando información financiera...'), findsOneWidget);

    // Esperar a que el mock resuelva el Future
    await tester.pumpAndSettle();

    // Comprobar elementos principales
    expect(find.text('Panel Principal'), findsOneWidget);
    expect(find.text('Cooperativa Financiera Futuro'), findsOneWidget);
    expect(find.text('Mis Cuentas'), findsOneWidget);
    expect(find.text('Cuenta de Ahorros Principal'), findsOneWidget);

    // Hacer scroll para asegurar que la siguiente cuenta en la lista es visible en viewport
    await tester.scrollUntilVisible(
      find.text('Fondo de Emergencia'),
      100.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fondo de Emergencia'), findsOneWidget);
  });

  testWidgets('Permite alternar la visibilidad de los saldos (Privacidad)',
      (WidgetTester tester) async {
    final mockRepo = MockDashboardRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DashboardScreen(repository: mockRepo),
      ),
    );

    await tester.pumpAndSettle();

    // Inicialmente los saldos son visibles
    expect(find.text('••••••••'), findsNothing);

    // Tocar el botón de visibilidad (ícono de ojo)
    final eyeButton = find.byTooltip('Ocultar saldos');
    expect(eyeButton, findsOneWidget);
    await tester.tap(eyeButton);
    await tester.pumpAndSettle();

    // Ahora los saldos deben estar enmascarados
    expect(find.text('••••••••'), findsWidgets);
  });
}
