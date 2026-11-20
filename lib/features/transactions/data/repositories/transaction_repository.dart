import '../../../../core/network/api_client.dart';
import '../models/transaction_model.dart';
import '../models/transfer_quote_model.dart';

abstract class TransactionRepository {
  Future<TransferQuoteModel> getQuote({
    required String sourceAccountId,
    required String destinationAccountNumber,
    required String amount,
  });

  Future<TransactionModel> transfer({
    required String sourceAccountId,
    required String destinationAccountNumber,
    required String amount,
    required String currency,
    required String pin,
    String? description,
    required String idempotencyKey,
  });

  Future<TransactionModel> deposit({
    required String accountId,
    required String amount,
    required String currency,
    String? description,
    required String idempotencyKey,
  });

  Future<TransactionModel> withdraw({
    required String accountId,
    required String amount,
    required String currency,
    required String pin,
    String? description,
    required String idempotencyKey,
  });

  Future<List<TransactionModel>> getHistory({
    String? accountId,
    String? type,
    int page = 1,
    int pageSize = 20,
  });
}

class ApiTransactionRepository implements TransactionRepository {
  final ApiClient _apiClient;

  ApiTransactionRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<TransferQuoteModel> getQuote({
    required String sourceAccountId,
    required String destinationAccountNumber,
    required String amount,
  }) async {
    final response = await _apiClient.post('/transactions/quote', {
      'source_account_id': sourceAccountId,
      'destination_account_number': destinationAccountNumber,
      'amount': amount,
    });
    return TransferQuoteModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<TransactionModel> transfer({
    required String sourceAccountId,
    required String destinationAccountNumber,
    required String amount,
    required String currency,
    required String pin,
    String? description,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      '/transactions/transfers',
      {
        'source_account_id': sourceAccountId,
        'destination_account_number': destinationAccountNumber,
        'amount': amount,
        'currency': currency,
        'pin': pin,
        'description': description,
      },
      idempotencyKey: idempotencyKey,
    );
    return TransactionModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<TransactionModel> deposit({
    required String accountId,
    required String amount,
    required String currency,
    String? description,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      '/transactions/deposits',
      {
        'account_id': accountId,
        'amount': amount,
        'currency': currency,
        'description': description,
      },
      idempotencyKey: idempotencyKey,
    );
    return TransactionModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<TransactionModel> withdraw({
    required String accountId,
    required String amount,
    required String currency,
    required String pin,
    String? description,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      '/transactions/withdrawals',
      {
        'account_id': accountId,
        'amount': amount,
        'currency': currency,
        'pin': pin,
        'description': description,
      },
      idempotencyKey: idempotencyKey,
    );
    return TransactionModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<TransactionModel>> getHistory({
    String? accountId,
    String? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    // Construye los filtros de forma segura y utiliza la paginación del backend.
    final queryParameters = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (accountId != null && accountId.trim().isNotEmpty) {
      queryParameters['account_id'] = accountId.trim();
    }
    if (type != null && type.trim().isNotEmpty) {
      queryParameters['type'] = type.trim().toUpperCase();
    }

    final query = Uri(queryParameters: queryParameters).query;
    final response = await _apiClient.get('/transactions?$query');
    if (response is! Map<String, dynamic>) {
      throw ApiException(statusCode: 502, message: 'Respuesta inválida al consultar el historial.');
    }
    final items = response['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class MockTransactionRepository implements TransactionRepository {
  final List<TransactionModel> _mockHistory = [
    TransactionModel(
      id: 'tx-001',
      type: 'TRANSFER',
      amount: '50000.00',
      currency: 'COP',
      feeAmount: '1500.00',
      exchangeRate: '1.000000',
      convertedAmount: '50000.00',
      destinationCurrency: 'COP',
      status: 'COMPLETED',
      description: 'Transferencia a cuenta •••• 8922',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    TransactionModel(
      id: 'tx-002',
      type: 'TRANSFER',
      amount: '100.00',
      currency: 'USD',
      feeAmount: '1.00',
      exchangeRate: '4000.000000',
      convertedAmount: '400000.00',
      destinationCurrency: 'COP',
      status: 'COMPLETED',
      description: 'Conversión USD a COP con tasa estática',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    TransactionModel(
      id: 'tx-003',
      type: 'DEPOSIT',
      amount: '1000000.00',
      currency: 'COP',
      feeAmount: '0.00',
      exchangeRate: '1.000000',
      convertedAmount: '1000000.00',
      destinationCurrency: 'COP',
      status: 'COMPLETED',
      description: 'Depósito en efectivo',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Future<TransferQuoteModel> getQuote({
    required String sourceAccountId,
    required String destinationAccountNumber,
    required String amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final numAmt = double.tryParse(amount) ?? 0.0;
    final isUSD = sourceAccountId.contains('903');
    final sourceCurr = isUSD ? 'USD' : 'COP';
    final destCurr = 'COP';
    final fee = isUSD ? 1.0 : 1500.0;
    final rate = isUSD ? 4000.0 : 1.0;
    final credited = numAmt * rate;

    return TransferQuoteModel(
      sourceCurrency: sourceCurr,
      destinationCurrency: destCurr,
      amountToDebit: numAmt.toStringAsFixed(2),
      feeAmount: fee.toStringAsFixed(2),
      totalDebited: (numAmt + fee).toStringAsFixed(2),
      exchangeRate: rate.toStringAsFixed(6),
      amountToCredit: credited.toStringAsFixed(2),
      hasCurrencyConversion: sourceCurr != destCurr,
      destinationAccountMasked: '•••• ${destinationAccountNumber.length >= 4 ? destinationAccountNumber.substring(destinationAccountNumber.length - 4) : '1234'}',
    );
  }

  @override
  Future<TransactionModel> transfer({
    required String sourceAccountId,
    required String destinationAccountNumber,
    required String amount,
    required String currency,
    required String pin,
    String? description,
    required String idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (pin != '1234') {
      throw ApiException(statusCode: 401, message: 'PIN incorrecto. (Usa: 1234)');
    }

    final newTx = TransactionModel(
      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
      type: 'TRANSFER',
      amount: amount,
      currency: currency,
      feeAmount: currency == 'USD' ? '1.00' : '1500.00',
      exchangeRate: '1.000000',
      convertedAmount: amount,
      destinationCurrency: currency,
      status: 'COMPLETED',
      idempotencyKey: idempotencyKey,
      description: description ?? 'Transferencia a $destinationAccountNumber',
      createdAt: DateTime.now(),
    );
    _mockHistory.insert(0, newTx);
    return newTx;
  }

  @override
  Future<TransactionModel> deposit({
    required String accountId,
    required String amount,
    required String currency,
    String? description,
    required String idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newTx = TransactionModel(
      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
      type: 'DEPOSIT',
      amount: amount,
      currency: currency,
      feeAmount: '0.00',
      exchangeRate: '1.000000',
      convertedAmount: amount,
      destinationCurrency: currency,
      status: 'COMPLETED',
      idempotencyKey: idempotencyKey,
      description: description ?? 'Depósito de fondos',
      createdAt: DateTime.now(),
    );
    _mockHistory.insert(0, newTx);
    return newTx;
  }

  @override
  Future<TransactionModel> withdraw({
    required String accountId,
    required String amount,
    required String currency,
    required String pin,
    String? description,
    required String idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (pin != '1234') {
      throw ApiException(statusCode: 401, message: 'PIN incorrecto. (Usa: 1234)');
    }
    final newTx = TransactionModel(
      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
      type: 'WITHDRAWAL',
      amount: amount,
      currency: currency,
      feeAmount: '0.00',
      exchangeRate: '1.000000',
      convertedAmount: amount,
      destinationCurrency: currency,
      status: 'COMPLETED',
      idempotencyKey: idempotencyKey,
      description: description ?? 'Retiro de efectivo',
      createdAt: DateTime.now(),
    );
    _mockHistory.insert(0, newTx);
    return newTx;
  }

  @override
  Future<List<TransactionModel>> getHistory({
    String? accountId,
    String? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    var filtered = _mockHistory.where((t) => type == null || t.type == type.toUpperCase()).toList();
    final start = (page - 1) * pageSize;
    if (start >= filtered.length) return [];
    return filtered.skip(start).take(pageSize).toList();
  }
}
