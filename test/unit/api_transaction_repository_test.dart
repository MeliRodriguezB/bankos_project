import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bankos_project/core/network/api_client.dart';
import 'package:bankos_project/features/transactions/data/repositories/transaction_repository.dart';


void main() {
  tearDown(() => ApiClient.setGlobalAuthToken(null));

  group('ApiTransactionRepository integration', () {
    test('transfer sends JWT, correlation and idempotency headers', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'id': 'tx-transfer-001',
            'type': 'TRANSFER',
            'amount': '1000.00',
            'currency': 'COP',
            'fee_amount': '1500.00',
            'exchange_rate': '1.000000',
            'converted_amount': '1000.00',
            'destination_currency': 'COP',
            'source_account_id': 'source-001',
            'destination_account_id': 'destination-001',
            'status': 'COMPLETED',
            'idempotency_key': 'retry-transfer-001',
            'correlation_id': 'corr-transfer-001',
            'description': 'Integration transfer',
            'created_at': '2026-11-20T08:00:00Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final apiClient = ApiClient(
        baseUrl: 'https://bankos.test/api/v1',
        client: client,
      );
      apiClient.setAuthToken('jwt-integration-test');
      final repository = ApiTransactionRepository(apiClient: apiClient);

      final transaction = await repository.transfer(
        sourceAccountId: 'source-001',
        destinationAccountNumber: '1000000002',
        amount: '1000.00',
        currency: 'COP',
        pin: '1234',
        description: 'Integration transfer',
        idempotencyKey: 'retry-transfer-001',
      );

      expect(capturedRequest.url.path, '/api/v1/transactions/transfers');
      expect(capturedRequest.headers['authorization'], 'Bearer jwt-integration-test');
      expect(capturedRequest.headers['idempotency-key'], 'retry-transfer-001');
      expect(capturedRequest.headers['x-correlation-id'], isNotEmpty);
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(payload['amount'], '1000.00');
      expect(payload['source_account_id'], 'source-001');
      expect(transaction.id, 'tx-transfer-001');
      expect(transaction.feeAmount, '1500.00');
      expect(transaction.correlationId, 'corr-transfer-001');
    });

    test('history sends pagination and filters to the v1 API', () async {
      late Uri requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'tx-history-001',
                'type': 'WITHDRAWAL',
                'amount': '2500.00',
                'currency': 'COP',
                'fee_amount': '0.00',
                'exchange_rate': '1.000000',
                'status': 'COMPLETED',
                'created_at': '2026-11-20T08:00:00Z',
              }
            ],
            'page': 2,
            'page_size': 5,
            'total': 7,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = ApiTransactionRepository(
        apiClient: ApiClient(
          baseUrl: 'https://bankos.test/api/v1',
          client: client,
        ),
      );

      final history = await repository.getHistory(
        accountId: 'account-001',
        type: 'withdrawal',
        page: 2,
        pageSize: 5,
      );

      expect(requestedUri.path, '/api/v1/transactions');
      expect(requestedUri.queryParameters, {
        'account_id': 'account-001',
        'type': 'WITHDRAWAL',
        'page': '2',
        'page_size': '5',
      });
      expect(history, hasLength(1));
      expect(history.single.type, 'WITHDRAWAL');
      expect(history.single.amount, '2500.00');
    });

    test('standardized API errors retain code and correlation ID', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'RATE_LIMIT_EXCEEDED',
                'message': 'Too many requests',
                'correlation_id': 'corr-rate-limit-001',
              }
            }),
            429,
            headers: {
              'content-type': 'application/json',
              'x-correlation-id': 'corr-rate-limit-001',
            },
          ));
      final repository = ApiTransactionRepository(
        apiClient: ApiClient(
          baseUrl: 'https://bankos.test/api/v1',
          client: client,
        ),
      );

      await expectLater(
        repository.getHistory(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having((error) => error.code, 'code', 'RATE_LIMIT_EXCEEDED')
              .having(
                (error) => error.correlationId,
                'correlationId',
                'corr-rate-limit-001',
              ),
        ),
      );
    });
  });
}


    test('deposit and withdrawal send idempotency keys and transaction payloads', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'id': 'tx-${requests.length}',
            'type': requests.length == 1 ? 'DEPOSIT' : 'WITHDRAWAL',
            'amount': '2500.00',
            'currency': 'COP',
            'fee_amount': '0.00',
            'exchange_rate': '1.000000',
            'converted_amount': '2500.00',
            'destination_currency': 'COP',
            'status': 'COMPLETED',
            'idempotency_key': request.headers['idempotency-key'],
            'correlation_id': 'corr-transaction-${requests.length}',
            'created_at': '2026-11-20T08:00:00Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = ApiTransactionRepository(
        apiClient: ApiClient(
          baseUrl: 'https://bankos.test/api/v1',
          client: client,
        ),
      );

      await repository.deposit(
        accountId: 'account-001',
        amount: '2500.00',
        currency: 'COP',
        description: 'Test deposit',
        idempotencyKey: 'deposit-api-test-001',
      );
      await repository.withdraw(
        accountId: 'account-001',
        amount: '2500.00',
        currency: 'COP',
        pin: '1234',
        description: 'Test withdrawal',
        idempotencyKey: 'withdraw-api-test-001',
      );

      expect(requests, hasLength(2));
      expect(requests[0].url.path, '/api/v1/transactions/deposits');
      expect(requests[0].headers['idempotency-key'], 'deposit-api-test-001');
      expect(
        jsonDecode(requests[0].body),
        containsPair('account_id', 'account-001'),
      );
      expect(requests[1].url.path, '/api/v1/transactions/withdrawals');
      expect(requests[1].headers['idempotency-key'], 'withdraw-api-test-001');
      expect(
        jsonDecode(requests[1].body),
        allOf(
          containsPair('account_id', 'account-001'),
          containsPair('pin', '1234'),
        ),
      );
    });
