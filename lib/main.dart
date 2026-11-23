import 'package:card_reader/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/scanner/bloc/card_scanner_bloc.dart';
import 'features/scanner/presentation/screens/card_scanner_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const CardReaderApp());
}

class CardReaderApp extends StatelessWidget {
  const CardReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safe Card Reader',
      theme: ThemeData.dark(useMaterial3: true)
          .copyWith(scaffoldBackgroundColor: const Color(0xFF0D1117)),
      home: BlocProvider(
        create: (_) => CardScannerBloc(),
        child: const CardScannerScreen(),
      ),
    );
  }
}
