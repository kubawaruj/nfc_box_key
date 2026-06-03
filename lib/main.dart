import 'package:flutter/material.dart';
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('NFC Box Key - Przemysł 4.0')),
        body: const HceControlWidget(),
      ),
    );
  }
}

class HceControlWidget extends StatefulWidget {
  const HceControlWidget({super.key});

  @override
  State<HceControlWidget> createState() => _HceControlWidgetState();
}

class _HceControlWidgetState extends State<HceControlWidget> {
  final _flutterNfcHcePlugin = FlutterNfcHce();
  bool _isHceActive = false;
  String _status = "Klucz nieaktywny";

  void _toggleHce() async {
    if (_isHceActive) {
      await _flutterNfcHcePlugin.startNfcHce("DISABLED");
      await _flutterNfcHcePlugin.stopNfcHce();
      setState(() {
        _isHceActive = false;
        _status = "Klucz nieaktywny";
      });
    } else {
      // "Payload" to tajny ciąg znaków, który odbierze Raspberry Pi
      // Może to być unikalny token wygenerowany dla studenta
      await _flutterNfcHcePlugin.startNfcHce("SECRET_STUDENT_TOKEN_2026");
      setState(() {
        _isHceActive = true;
        _status = "Emulacja uruchomiona. Zbliż telefon do czytnika.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_status, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _toggleHce,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isHceActive ? Colors.red : Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: Text(_isHceActive ? 'Dezaktywuj klucz' : 'Aktywuj klucz', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}