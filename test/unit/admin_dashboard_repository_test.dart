import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bankos_project/core/network/api_client.dart';
import 'package:bankos_project/features/admin/data/models/tenant_config_model.dart';
import 'package:bankos_project/features/admin/data/repositories/admin_dashboard_repository.dart';

Map<String, dynamic> _configJson() => {
      'id': 'tenant-001',
      'name': 'Cooperativa Futuro',
      'slug': 'cooperativa-futuro',
      'status': 'ACTIVE',
      'max_transfer_amount': '3000000.00',
      'transfer_fees': {'COP': '1200.00', 'USD': '1.25'},
      'transfer_fee_percent': '0.0100',
      'primary_currency': 'COP',
      'supported_currencies': ['COP', 'USD'],
      'exchange_rates': {'COP/USD': '0.00025', 'USD/COP': '4000.00'},
      'webhook_url': 'https://hooks.example.test/bankos',
    };

void main() {
  tearDown(() => ApiClient.setGlobalAuthToken(null));

  test('tenant settings are loaded from the authenticated tenant endpoint', () async {
    late http.Request captured;
    final repository = AdminDashboardRepository(
      client: ApiClient(
        baseUrl: 'https://bankos.test/api/v1',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(_configJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final config = await repository.getTenantConfig();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/tenant/config');
    expect(config.maxTransferAmount, '3000000.00');
    expect(config.transferFees['COP'], '1200.00');
    expect(config.supportedCurrencies, ['COP', 'USD']);
    expect(config.webhookUrl, 'https://hooks.example.test/bankos');
  });

  test('admin settings are saved with PATCH and the full policy payload', () async {
    late http.Request captured;
    final repository = AdminDashboardRepository(
      client: ApiClient(
        baseUrl: 'https://bankos.test/api/v1',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(_configJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    const config = TenantConfigModel(
      maxTransferAmount: '3000000.00',
      transferFees: {'COP': '1200.00', 'USD': '1.25'},
      transferFeePercent: '0.0100',
      primaryCurrency: 'COP',
      supportedCurrencies: ['COP', 'USD'],
      exchangeRates: {'COP/USD': '0.00025', 'USD/COP': '4000.00'},
      webhookUrl: 'https://hooks.example.test/bankos',
    );

    final saved = await repository.updateTenantConfig(config);
    final payload = jsonDecode(captured.body) as Map<String, dynamic>;

    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/api/v1/tenant/config');
    expect(payload['max_transfer_amount'], '3000000.00');
    expect(payload['transfer_fees']['COP'], '1200.00');
    expect(payload['supported_currencies'], ['COP', 'USD']);
    expect(payload['exchange_rates']['USD/COP'], '4000.00');
    expect(payload['webhook_url'], 'https://hooks.example.test/bankos');
    expect(saved.transferFeePercent, '0.0100');
  });
}
