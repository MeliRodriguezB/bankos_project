import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bankos_project/features/admin/data/models/tenant_config_model.dart';
import 'package:bankos_project/features/admin/data/repositories/admin_dashboard_repository.dart';
import 'package:bankos_project/features/admin/presentation/screens/tenant_settings_screen.dart';

class _FakeAdminRepository extends AdminDashboardRepository {
  TenantConfigModel savedConfig;

  _FakeAdminRepository(this.savedConfig);

  @override
  Future<TenantConfigModel> getTenantConfig() async => savedConfig;

  @override
  Future<TenantConfigModel> updateTenantConfig(TenantConfigModel config) async {
    savedConfig = config;
    return config;
  }
}

void main() {
  testWidgets('admin can edit and save tenant transfer and webhook settings', (tester) async {
    final repository = _FakeAdminRepository(
      const TenantConfigModel(
        maxTransferAmount: '1000000.00',
        transferFees: {'COP': '1000.00', 'USD': '1.00'},
        transferFeePercent: '0.005',
        primaryCurrency: 'COP',
        supportedCurrencies: ['COP', 'USD'],
        exchangeRates: {'COP/USD': '0.00025', 'USD/COP': '4000.00'},
        webhookUrl: 'https://hooks.example.test/bankos',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: TenantSettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(7));
    await tester.enterText(fields.at(0), '3000000.00');
    await tester.enterText(fields.at(1), '0.01');
    await tester.enterText(fields.at(2), 'COP');
    await tester.enterText(fields.at(3), 'COP, USD');
    await tester.enterText(fields.at(4), '{"COP":"1200.00","USD":"1.25"}');
    await tester.enterText(fields.at(5), '{"COP/USD":"0.00025","USD/COP":"4000.00"}');
    await tester.enterText(fields.at(6), '');

    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();

    expect(repository.savedConfig.maxTransferAmount, '3000000.00');
    expect(repository.savedConfig.transferFeePercent, '0.01');
    expect(repository.savedConfig.transferFees['COP'], '1200.00');
    expect(repository.savedConfig.supportedCurrencies, ['COP', 'USD']);
    expect(repository.savedConfig.exchangeRates['USD/COP'], '4000.00');
    expect(repository.savedConfig.webhookUrl, isNull);
    expect(find.text('Configuración institucional actualizada.'), findsOneWidget);
  });
}
