import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('NFC Box Key')),
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
  final _tokenController = TextEditingController();
  
  bool _isHceActive = false;
  String _status = "Klucz nieaktywny";
  String? _errorText; // Zmienna przechowująca komunikat o błędzie dla TextField

  @override
  void initState() {
    super.initState();
    _initUserToken();
  }

  // --- LOGIKA PIERWSZEGO URUCHOMIENIA ---
  void _initUserToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedToken = prefs.getString('user_nfc_token');

    if (savedToken == null || savedToken.isEmpty) {
      _generateAndSaveRandomToken();
    } else {
      setState(() {
        _tokenController.text = savedToken;
        _errorText = null;
      });
    }
  }

  // --- PRODUKCJA NOWEGO LOSOWEGO TOKENU (UUID) ---
  void _generateAndSaveRandomToken() async {
    final prefs = await SharedPreferences.getInstance();
    var uuid = const Uuid();
    String newToken = uuid.v4().substring(0, 8).toUpperCase();
    
    await prefs.setString('user_nfc_token', newToken);
    setState(() {
      _tokenController.text = newToken;
      _errorText = null;
    });
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1000),
        content: Text('Wygenerowano nowy token: $newToken')
        ),
    );
  }

  // --- CAŁKOWITE USUNIĘCIE KLUCZA Z PAMIĘCI TELEFONU ---
  void _deleteTokenFromMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_nfc_token'); // Czyszczenie SharedPreferences
    
    setState(() {
      _tokenController.clear();
      _errorText = "Token został usunięty z pamięci!";
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: const Duration(milliseconds: 1000),
        content: Text('Pamięć wyczyszczona. Wpisz coś lub wylosuj nowy token.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // --- ZAPIS ZMIENIONEGO TOKENU Z WALIDACJĄ ---
  bool _saveModifiedToken() {
    // Sprawdzamy czy użytkownik nie zostawił pustego pola lub samych spacji
    if (_tokenController.text.trim().isEmpty) {
      setState(() {
        _errorText = "Pole nie może być puste! Wpisz token.";
      });
      return false;
    }

    setState(() {
      _errorText = null; // Czyszczenie błędu jeśli wszystko jest OK
    });

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('user_nfc_token', _tokenController.text.trim());
    });

    return true;
  }

  // --- STEROWANIE EMULACJĄ HCE ---
  void _toggleHce() async {
    if (_isHceActive) {
      // Wyłączanie HCE (Trik z podstawieniem tokenu anulującego)
      await _flutterNfcHcePlugin.startNfcHce("DISABLED");
      await _flutterNfcHcePlugin.stopNfcHce();
      setState(() {
        _isHceActive = false;
        _status = "Klucz nieaktywny";
      });
    } else {
      // Walidacja przed uruchomieniem HCE!
      if (!_saveModifiedToken()) {
        // Jeśli pole jest puste, przerywamy aktywację i rzucamy ostrzeżenie
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: const Duration(milliseconds: 1000),
            content: Text('BŁĄD: Nie można aktywować pustego klucza!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Jeśli test przeszedł pomyślnie, uruchamiamy nadawanie sygnału
      String currentToken = _tokenController.text.trim();
      await _flutterNfcHcePlugin.startNfcHce(currentToken);
      setState(() {
        _isHceActive = true;
        _status = "Emulacja aktywna. Zbliż telefon do czytnika.";
      });
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Karta statusu
          Card(
            color: _isHceActive ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _status,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isHceActive ? Colors.green.shade900 : Colors.red.shade900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 25),

          // SEKCJA EDYCJI I WALIDACJI
          const Text(
            "Twój unikalny Token użytkownika:",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _tokenController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: 'Wpisz klucz dostępu...',
                    prefixIcon: const Icon(Icons.vpn_key),
                    errorText: _errorText, // Wyświetla czerwone ostrzeżenie pod spodem
                  ),
                  enabled: !_isHceActive,
                  onChanged: (text) {
                    // Dynamicznie usuwaj komunikat o błędzie, gdy użytkownik zacznie pisać
                    if (text.trim().isNotEmpty && _errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                ),
              ),
              if (!_isHceActive && _tokenController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Kopiuj token',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _tokenController.text));
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          duration: const Duration(milliseconds: 1000),
                          content: Text('Skopiowano token do schowka!')
                          ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),

          // PRZYCISKI ZARZĄDZANIA PAMIĘCIĄ (Widoczne tylko gdy klucz jest wyłączony)
          if (!_isHceActive) ...[
            ElevatedButton.icon(
              onPressed: () {
                if (_saveModifiedToken()) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: const Duration(milliseconds: 1000),
                      content: Text('Zapisano zmiany w pamięci!')
                      ),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Zapisz obecne zmiany'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generateAndSaveRandomToken,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Losuj nowy token'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteTokenFromMemory,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Usuń z pamięci'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 35),

          // GŁÓWNY PRZYCISK AKTYWACJI HCE
          ElevatedButton(
            onPressed: _toggleHce,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isHceActive ? Colors.red : Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _isHceActive ? 'DEZAKTYWUJ KLUCZ' : 'AKTYWUJ KLUCZ',
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}