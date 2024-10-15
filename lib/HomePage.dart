import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:translator/translator.dart'; // For translation

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String translatedText = '';
  bool _isProcessing = false;
  Timer? _timer; // Timer to handle periodic text update

  String _selectedFromLanguage = 'en'; // Default source language
  String _selectedToLanguage = 'es'; // Default target language

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'code': 'en'},
    {'name': 'Spanish', 'code': 'es'},
    {'name': 'French', 'code': 'fr'},
    {'name': 'German', 'code': 'de'},
    {'name': 'Chinese', 'code': 'zh'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    // Start the timer to trigger text capture and translation every 5 seconds
    _startAutoCapture();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final CameraDescription camera = cameras.first;

    _cameraController = CameraController(camera, ResolutionPreset.medium);
    await _cameraController?.initialize();

    if (!mounted) return;

    setState(() {
      _isCameraInitialized = true;
    });
  }

  // Method to automatically capture and recognize text every 5 seconds
  void _startAutoCapture() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) async {
      if (_isCameraInitialized && !_isProcessing) {
        await _captureAndRecognizeText();
      }
    });
  }

  Future<void> _captureAndRecognizeText() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Capture the image
      final image = await _cameraController!.takePicture();

      // Initialize text recognizer
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      // Create input image from file path
      final inputImage = InputImage.fromFilePath(image.path);

      // Process the image to recognize text
      final RecognizedText recognizedTextObject = await textRecognizer.processImage(inputImage);

      final recognizedText = recognizedTextObject.text.isNotEmpty
          ? recognizedTextObject.text
          : 'No text recognized.';

      // Automatically translate the recognized text
      await _translateText(recognizedText, _selectedFromLanguage, _selectedToLanguage);

      // Optionally delete the image file to save storage
      await File(image.path).delete();

      // Clear the translated text after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        setState(() {
          translatedText = '';
        });
      });
    } catch (e) {
      print('Error during text recognition: $e');
    }

    setState(() {
      _isProcessing = false;
    });
  }

  Future<void> _translateText(String text, String fromLang, String toLang) async {
    final translator = GoogleTranslator();
    try {
      final translation = await translator.translate(text, from: fromLang, to: toLang);
      setState(() {
        translatedText = translation.text;
      });
    } catch (e) {
      print('Translation Error: $e');
    }
  }


  Widget _buildOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        color: Colors.black54, // Semi-transparent background for the text
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              translatedText.isNotEmpty
                  ? 'Translated Text:\n$translatedText'
                  : 'Awaiting text capture...',
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[100],
      appBar: AppBar(
        title: const Text('Live Text Recognition & Translation'),
        backgroundColor: Colors.purple,
      ),
      body: _isCameraInitialized
          ? Stack(
        children: [
          CameraPreview(_cameraController!), // Show live camera feed
          _buildOverlay(), // Overlay the translated text on top of camera preview
        ],
      )
          : const Center(child: CircularProgressIndicator()), // Show loading indicator while camera initializes
      bottomNavigationBar: _buildLanguageSelector(), // Language dropdown at the bottom
    );
  }


  Widget _buildLanguageSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // From Language Dropdown
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('From:'),
              DropdownButton<String>(
                value: _selectedFromLanguage,
                items: _languages.map((Map<String, String> language) {
                  return DropdownMenuItem<String>(
                    value: language['code'],
                    child: Text(language['name']!),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFromLanguage = newValue!;
                  });
                },
              ),
            ],
          ),
          // To Language Dropdown
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('To:'),
              DropdownButton<String>(
                value: _selectedToLanguage,
                items: _languages.map((Map<String, String> language) {
                  return DropdownMenuItem<String>(
                    value: language['code'],
                    child: Text(language['name']!),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedToLanguage = newValue!;
                    // Translate again when the target language changes
                    if (translatedText.isNotEmpty) {
                      _translateText(translatedText, _selectedFromLanguage, _selectedToLanguage);
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
