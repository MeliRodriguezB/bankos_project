import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';
import '../../data/models/admin_dashboard_model.dart';
import '../../data/repositories/admin_dashboard_repository.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AdminDashboardRepository? repository;
  const AdminDashboardScreen({super.key, this.repository});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminDashboardRepository _repo;
  AdminDashboardModel? _data;
  List<AdminBankModel> _banks = [];
  List<AdminAccountModel> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AdminDashboardRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.getDashboard();
      final banks = await _repo.getBanks();
      final accounts = await _repo.getAccounts();
      if (!mounted) return;
      setState(() { _data = data; _banks = banks; _accounts = accounts; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    ApiClient.setGlobalAuthToken(null);
    await SessionStorage().clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  int _color(String hex) => int.parse('FF${hex.replaceFirst('#', '')}', radix: 16);

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(15),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ],
        )),
      ]),
    );
  }

  Future<void> _createBank() async {
    final name = TextEditingController();
    final slug = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar institución'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nombre del banco'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),
            TextFormField(
              controller: slug,
              decoration: const InputDecoration(labelText: 'Slug (ej. banco-nuevo)'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        await _repo.createBank(name: name.text.trim(), slug: slug.text.trim());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Institución creada')));
        await _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear: $e')));
      }
    }
    name.dispose();
    slug.dispose();
  }

  Future<void> _toggleBank(AdminBankModel bank) async {
    final nextStatus = bank.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await _repo.updateBank(bank, status: nextStatus);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    }
  }

  Widget _bankCard(AdminBankModel bank) {
    final primary = Color(_color(bank.primaryColor));
    final active = bank.status == 'ACTIVE';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 6, color: primary),
        ListTile(
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: primary.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.account_balance_rounded, color: primary),
          ),
          title: Text(bank.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(bank.slug),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active ? AppTheme.success.withOpacity(.1) : AppTheme.warning.withOpacity(.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(active ? 'ACTIVO' : 'INACTIVO', style: TextStyle(color: active ? AppTheme.success : AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            _colorDot(bank.primaryColor, 'Primario'),
            const SizedBox(width: 12),
            _colorDot(bank.secondaryColor, 'Secundario'),
            const SizedBox(width: 12),
            _colorDot(bank.accentColor, 'Acento'),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _toggleBank(bank),
              icon: Icon(active ? Icons.pause_circle_outline : Icons.play_circle_outline),
              label: Text(active ? 'Desactivar' : 'Activar'),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _colorDot(String hex, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 13, height: 13, decoration: BoxDecoration(color: Color(_color(hex)), shape: BoxShape.circle, border: Border.all(color: AppTheme.border))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
  ]);

  Widget _accountCard(AdminAccountModel account) => Card(child: ListTile(
    leading: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.accent),
    title: Text(account.alias),
    subtitle: Text('${account.bank} · ${account.ownerName} · ${account.accountNumberMasked}', maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${account.currency} ${account.balance}', style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(account.status, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    ]),
  ));

  Widget _errorView() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off, size: 44, color: AppTheme.error),
      const Text('No se pudo cargar la administración global'),
      Text(_error!, textAlign: TextAlign.center),
      FilledButton(onPressed: _load, child: const Text('Reintentar')),
    ]),
  ));

  Widget _dashboardContent() {
    final wide = MediaQuery.of(context).size.width > 720;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CONTROL CENTRAL', style: TextStyle(color: Colors.white70, letterSpacing: 1.2, fontSize: 11)),
            SizedBox(height: 8),
            Text('Panel de plataforma', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Supervisión de instituciones, cuentas y operaciones', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: wide ? 3 : 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: wide ? 2.0 : 1.35,
          children: [
            _metric('Instituciones', '${_data?.banksTotal ?? 0}', Icons.account_balance),
            _metric('Bancos activos', '${_data?.banksActive ?? 0}', Icons.verified_outlined),
            _metric('Usuarios', '${_data?.usersTotal ?? 0}', Icons.people_alt_outlined),
            _metric('Cuentas', '${_data?.accountsTotal ?? 0}', Icons.account_balance_wallet_outlined),
            _metric('Cuentas activas', '${_data?.accountsActive ?? 0}', Icons.check_circle_outline),
            _metric('Transacciones', '${_data?.transactionsTotal ?? 0}', Icons.receipt_long_outlined),
          ],
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text('Instituciones financieras', style: Theme.of(context).textTheme.titleLarge)),
          FilledButton.icon(onPressed: _createBank, icon: const Icon(Icons.add), label: const Text('Agregar')),
        ]),
        const SizedBox(height: 8),
        if (_banks.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No hay instituciones registradas')))
        else
          ..._banks.map(_bankCard),
        const SizedBox(height: 18),
        Text('Cuentas de la plataforma', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_accounts.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No hay cuentas registradas')))
        else
          ..._accounts.map(_accountCard),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('BankOS · Plataforma'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Actualizar'),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Cerrar sesión'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null ? _errorView() : _dashboardContent()),
    );
  }
}
