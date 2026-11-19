import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';

class BankOsApp extends StatefulWidget {
  const BankOsApp({super.key});

  @override
  State<BankOsApp> createState() => _BankOsAppState();
}

class _BankOsAppState extends State<BankOsApp> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_CO', null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BankOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
