

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:async';

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;
  final Function(String name, String date) onSave; // Tunneln till HomeScreen

  const TakePictureScreen({
    super.key,
    required this.camera,
    required this.onSave,
  });

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  final TextEditingController _nameController = TextEditingController();
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final TextRecognizer _textRecognizer = TextRecognizer();

  Timer? _scanTimer;
  bool _isScanning = false; // Spärr för automatisk scanning

 @override
void initState() {
  super.initState();
  _controller = CameraController(widget.camera, ResolutionPreset.medium);
  
  // Vi startar timern, men vi lägger in en kontroll inuti
  _initializeControllerFuture = _controller.initialize().then((_) {
    if (!mounted) return;
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      print("Tick... scanning: $_isScanning"); // Håll koll i konsolen!
      _autoCapture();
    });
  });
}

  @override
void dispose() {
  // 1. Stoppa timern först av allt!
  _scanTimer?.cancel();
  
  // 2. Stäng ner kameran
  _controller.dispose();
  
  // 3. Stäng ner textigenkännaren
  _textRecognizer.close();
  
  super.dispose();
}


  Future<void> _scanText(String imagePath) async {
  try {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    String? foundDate = _extractDate(recognizedText.text);

    if (foundDate != null) {
      String cleanDate = formatToStandardDate(foundDate);
      // Vänta på att användaren stänger dialogen
      await _showSaveDialog(cleanDate);
      // Lås upp EFTER att dialogen stängts
      _isScanning = false; 
    } else {
      // Inget datum hittat? Lås upp direkt!
      _isScanning = false;
    }
  } catch (e) {
    print("Fel i scanText: $e");
    _isScanning = false; // Lås upp även vid fel!
  }
} //test

  void _testFoundDate() {
    //funktionalitet för testknappen, buggsymbolen i appen
    String fakeDate = "2026-05-20";
    _nameController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Spara vara"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Hittat datum: $fakeDate"),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Vad är det för vara?",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Avbryt"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                // FIX 1: Använd widget.onSave istället för _myFridge.add
                // Vi skickar datan till HomeScreen istället för att spara den här
                widget.onSave(_nameController.text, fakeDate);

                _nameController.clear();
                Navigator.pop(context); // Stänger dialogen
                Navigator.pop(context); // Går tillbaka till HomeScreen
              }
            },
            child: const Text("Spara i kylen"),
          ),
        ],
      ),
    );
  }

Future<void> _showSaveDialog(String date) { // Du kan ta bort 'async' här om du vill, eftersom vi returnerar direkt
  _nameController.clear();
  
  // LÄGG TILL 'return' HÄR:
  return showDialog(
    context: context,
    // Ett bra tips: lägg till barrierDismissible: false om du inte vill 
    // att autoscan ska starta av misstag om man råkar klicka utanför rutan.
    barrierDismissible: false, 
    builder: (context) => AlertDialog(
      title: const Text("Vara hittad!"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Utgångsdatum: $date"),
          TextField(
            controller: _nameController,
            autofocus: true, // Gör det smidigare för användaren!
            decoration: const InputDecoration(
              labelText: "Vad är det för vara?",
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            _scanTimer?.cancel();
            // Här sparar vi och stänger ner
            widget.onSave(_nameController.text, date);
            Navigator.pop(context); // Stänger dialogen
            Navigator.pop(context); // Går tillbaka till listan
          },
          child: const Text("Spara"),
        ),
      ],
    ),
  );
}

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Skanna vara'),
      backgroundColor: Colors.green.shade100,
    ),
    body: FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return CameraPreview(_controller);
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    ),
    // Här har vi städat upp i din Column
    floatingActionButton: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: "btn1",
          onPressed: _testFoundDate, // Din test-knapp
          backgroundColor: Colors.orange,
          child: const Icon(Icons.bug_report),
        ),
        const SizedBox(height: 12),
        
        // Om du vill ha en manuell skanningsknapp också, gör så här:
        FloatingActionButton(
          heroTag: "btn2",
          onPressed: () => _autoCapture(), // Anropar din nya auto-metod
          backgroundColor: Colors.green,
          child: const Icon(Icons.camera_alt),
        ),
      ],
    ),
  );
}

 Future<void> _autoCapture() async {
  // 1. Kontrollera om vi kan scanna
  if (!mounted || !_controller.value.isInitialized || _isScanning) {
    return;
  }

  // 2. Lås
  setState(() {
    _isScanning = true;
  });

  try {
    print("Tar bild...");
    final image = await _controller.takePicture();
    
    print("Skannar text...");
    await _scanText(image.path); 
    
    // NOTERA: _isScanning sätts till false inuti _scanText
  } catch (e) {
    print('Fel i autoCapture: $e');
    setState(() {
      _isScanning = false; 
    });
  }
}

  String? _extractDate(String text) {
    final List<RegExp> priorityPatterns = [
      // 1. Fullständiga datum med 4-siffrigt år (t.ex. 08.12.2030)
      // Ändra i din _extractDate lista:
RegExp(r'\d{2}[-/. ]\d{2}[-/. ]\d{4}'), // 08.12.2030
RegExp(r'\d{2}[-/. ]\d{4}'),           // 11.2026,

      // 2. MÅNAD OCH ÅR (Din Timjan: 11.2026)
      // Vi tar bort \b och tillåter punkt/streck/mellanslag
      RegExp(r'\d{2}[-/. ]\d{4}'),

      // 3. Fullständiga datum med 2-siffrigt år (t.ex. 08.12.26)
      RegExp(r'\d{2}[-/. ]\d{2}[-/. ]\d{2}'),

      // 4. Bara siffror (Kompakta format)
      RegExp(r'\d{8}'),
      RegExp(r'\d{6}'),
    ];

    for (var pattern in priorityPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  String formatToStandardDate(String foundDate) {
  String cleanedFoundDate = foundDate.trim();
  String raw = cleanedFoundDate.replaceAll(RegExp(r'[^0-9]'), '');

  // FALL A: 8 siffror (t.ex. 08122030)
  if (raw.length == 8) {
    String dag = raw.substring(0, 2);
    String manad = raw.substring(2, 4);
    String ar = raw.substring(4, 8);
    return "$dag-$manad-$ar"; // Här använder vi 'dag' istället för 'xx'
  }

  // FALL B: 6 siffror (t.ex. 081226 eller 112026)
  if (raw.length == 6) {
    // Om det är Timjan-formatet (MM.YYYY -> 11.2026)
    if (cleanedFoundDate.length == 7) {
      String manad = raw.substring(0, 2);
      String ar = raw.substring(2, 6);
      return "xx-$manad-$ar"; // Här är det rätt med 'xx'
    }
    
    // Annars är det DDMMÅÅ (t.ex. 081226)
    String dag = raw.substring(0, 2);
    String manad = raw.substring(2, 4);
    String ar = "20" + raw.substring(4, 6);
    return "$dag-$manad-$ar"; // Här använder vi 'dag'!
  }

  // FALL C: 4 siffror (MMÅÅ)
  if (raw.length == 4) {
    String manad = raw.substring(0, 2);
    String ar = "20" + raw.substring(2, 4);
    return "xx-$manad-$ar";
  }

  return foundDate;
}
}
