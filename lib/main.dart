import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/p2p/bloc/p2p_bloc.dart';
import 'features/scanner/bloc/card_scanner_bloc.dart';
import 'features/scanner/presentation/screens/card_scanner_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CardReaderApp());
}

class CardReaderApp extends StatelessWidget {
  const CardReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safe Card Reader',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF161B22),
          contentTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CardScannerBloc()),
          BlocProvider(create: (_) => P2pBloc()),
        ],
        child: const CardScannerScreen(),
      ),
    );
  }
}
