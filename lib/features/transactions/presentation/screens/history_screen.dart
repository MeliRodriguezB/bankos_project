import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';

class HistoryScreen extends StatefulWidget {
  final TransactionRepository repository;

  const HistoryScreen({super.key, required this.repository});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selectedFilter; // null = Todos, TRANSFER, DEPOSIT, WITHDRAWAL
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.repository.getHistory(type: _selectedFilter);
      if (mounted) {
        setState(() {
          _transactions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Movimientos'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
        children: [
          // Barra de Filtros Rápidos (Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('Todos', null),
                const SizedBox(width: 8),
                _buildFilterChip('Transferencias', 'TRANSFER'),
                const SizedBox(width: 8),
                _buildFilterChip('Depósitos', 'DEPOSIT'),
                const SizedBox(width: 8),
                _buildFilterChip('Retiros', 'WITHDRAWAL'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de Transacciones
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildFilterChip(String label, String? typeValue) {
    final isSelected = _selectedFilter == typeValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = typeValue);
          _fetchHistory();
        }
      },
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 40),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchHistory,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron movimientos registrados.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es_CO');

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final tx = _transactions[index];
          final dateStr = dateFormat.format(tx.createdAt.toLocal());

          final IconData icon;
          final Color iconBg;
          final Color iconColor;
          final String typeTitle;

          switch (tx.type) {
            case 'DEPOSIT':
              icon = Icons.arrow_downward_rounded;
              iconBg = const Color(0xFFDCFCE7);
              iconColor = const Color(0xFF166534);
              typeTitle = 'Depósito';
              break;
            case 'WITHDRAWAL':
              icon = Icons.arrow_upward_rounded;
              iconBg = const Color(0xFFFEE2E2);
              iconColor = const Color(0xFF991B1B);
              typeTitle = 'Retiro';
              break;
            default:
              icon = Icons.swap_horiz_rounded;
              iconBg = const Color(0xFFE0F2FE);
              iconColor = const Color(0xFF0369A1);
              typeTitle = 'Transferencia';
          }

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: iconBg,
                        radius: 20,
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              tx.description ?? dateStr,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(tx.amount, tx.currency),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Alertas visuales de costos (comisiones y conversión)
                  if (tx.hasFee || tx.hasConversion) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (tx.hasFee)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Text(
                              'Comisión: \$ ${tx.feeAmount} ${tx.currency}',
                              style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (tx.hasConversion)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              'Conversión: 1 ${tx.currency} = ${tx.exchangeRate} ${tx.destinationCurrency}',
                              style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
