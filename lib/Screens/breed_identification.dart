import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
// NOTE: Assuming you replaced the problematic package with a working one
// or fixed the original package in pubspec.yaml. Using standard import for logic.
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img_lib;

// Enum to manage different UI states for a cleaner experience
enum AppState { idle, loadingModel, modelReady, analyzing, resultReady }

class BreedIdentificationScreen extends StatefulWidget {
  const BreedIdentificationScreen({super.key});

  @override
  State<BreedIdentificationScreen> createState() =>
      _BreedIdentificationScreenState();
}

class _BreedIdentificationScreenState extends State<BreedIdentificationScreen> {
  // --- Model Constants ---
  static const String MODEL_PATH = 'assets/dog_breed_model.tflite';
  static const String LABEL_PATH = 'assets/labels.txt';
  static const int INPUT_SIZE = 224;
  static const int NUM_CLASSES = 37;
  static const double CONFIDENCE_THRESHOLD = 50.0; // 50% threshold

  // --- State Variables ---
  Interpreter? _interpreter;
  List<String> _labels = [];
  File? _selectedImage;
  AppState _appState = AppState.loadingModel;
  String _predictionResult = "Loading model...";

  @override
  void initState() {
    super.initState();
    _loadModelAndLabels();
  }

  /// Loads the TFLite model and labels from assets
  Future<void> _loadModelAndLabels() async {
    try {
      // NOTE: This assumes tflite_flutter is working after package replacement/fix.
      _interpreter = await Interpreter.fromAsset(MODEL_PATH);
      String labelData = await rootBundle.loadString(LABEL_PATH);
      _labels = labelData.split('\n').where((s) => s.trim().isNotEmpty).toList();

      if (_labels.length != NUM_CLASSES) {
        throw Exception("Label count doesn't match model output.");
      }

      setState(() {
        _appState = AppState.modelReady;
        _predictionResult = "Upload a picture of your pet to identify its breed";
      });
    } catch (e) {
      setState(() {
        _appState = AppState.idle;
        _predictionResult = "Error loading model: \n$e";
      });
    }
  }

  /// Shows the bottom sheet to select image source (Camera or Gallery)
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _processImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _processImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Handles image picking and state transition
  Future<void> _processImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _appState = AppState.analyzing;
        _predictionResult = "Analyzing...";
      });
      await _runInference();
    }
  }

  /// Preprocesses the image and runs inference
  Future<void> _runInference() async {
    if (_interpreter == null || _selectedImage == null) return;

    try {
      // 1. PREPROCESSING
      final imageBytes = await _selectedImage!.readAsBytes();
      final originalImage = img_lib.decodeImage(imageBytes);
      if (originalImage == null) throw Exception("Could not decode image.");

      final resizedImage = img_lib.copyResize(
        originalImage,
        width: INPUT_SIZE,
        height: INPUT_SIZE,
      );

      final normalizedData = Float32List(1 * INPUT_SIZE * INPUT_SIZE * 3);
      int index = 0;

      for (int y = 0; y < INPUT_SIZE; y++) {
        for (int x = 0; x < INPUT_SIZE; x++) {
          final pixel = resizedImage.getPixel(x, y);

          // Normalization and channel access
          normalizedData[index++] = (pixel.getChannel(img_lib.Channel.red) / 127.5) - 1.0;
          normalizedData[index++] = (pixel.getChannel(img_lib.Channel.green) / 127.5) - 1.0;
          normalizedData[index++] = (pixel.getChannel(img_lib.Channel.blue) / 127.5) - 1.0;
        }
      }
      final input = normalizedData.reshape([1, INPUT_SIZE, INPUT_SIZE, 3]);

      // 2. RUN INFERENCE
      final output = Float32List(1 * NUM_CLASSES).reshape([1, NUM_CLASSES]);
      _interpreter!.run(input, output);

      // 3. POST-PROCESSING (Softmax & Confidence Check)
      final probabilities = _softmax(output[0] as List<double>);

      double maxScore = 0;
      int bestIndex = -1;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxScore) {
          maxScore = probabilities[i];
          bestIndex = i;
        }
      }

      // 4. UPDATE UI
      if (bestIndex != -1) {
        String breed = _labels[bestIndex];
        double confidence = maxScore * 100;

        setState(() {
          _appState = AppState.resultReady;

          if (confidence < CONFIDENCE_THRESHOLD) { // Check if below 50%
            _predictionResult = "Confidence too low (${confidence.toStringAsFixed(2)}%).\nPlease re-upload a clearer image.";
          } else {
            // Success: Show breed and high confidence
            _predictionResult = "Predicted Breed: $breed\nConfidence: ${confidence.toStringAsFixed(2)}%";
          }
        });
      } else {
        throw Exception("Model returned no valid prediction.");
      }
    } catch (e) {
      setState(() {
        _appState = AppState.modelReady;
        _predictionResult = "Inference failed: $e";
      });
    }
  }

  /// Helper function to apply Softmax to the model's raw output (logits).
  List<double> _softmax(List<double> scores) {
    double maxScore = scores.reduce(max);
    List<double> expScores = scores.map((s) => exp(s - maxScore)).toList();
    double sumExpScores = expScores.reduce((a, b) => a + b);
    return expScores.map((s) => s / sumExpScores).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if the button should be active
    final bool isButtonActive = _appState == AppState.modelReady || _appState == AppState.resultReady;

    // --- Safe access logic for results (fixes RangeError) ---
    final bool hasPredictionResult = _predictionResult.contains('\n');
    final String displayMessage = hasPredictionResult ? _predictionResult.split('\n')[0] : _predictionResult;
    final String? displayConfidence = hasPredictionResult && _predictionResult.split('\n').length > 1 ? _predictionResult.split('\n')[1] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Breed Identification"),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Display message (Instructions, Loading, Analyzing, or Breed Name)
            Text(
              displayMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- Image Display ---
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                border: Border.all(color: Colors.teal, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _selectedImage == null
                  ? const Icon(Icons.pets, size: 80, color: Colors.black54)
                  : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              ),
            ),

            const SizedBox(height: 20),

            // --- Button State & Action ---
            ElevatedButton.icon(
              onPressed: isButtonActive ? _showImageSourceDialog : null,
              icon: _appState == AppState.loadingModel || _appState == AppState.analyzing
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: Text(_getButtonText()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),

            const SizedBox(height: 20),

            // --- Confidence Display (Uses safe access logic) ---
            if (displayConfidence != null)
              Text(
                displayConfidence,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  // Highlight low confidence in red/orange
                  color: displayConfidence.contains('too low') ? Colors.deepOrange : Colors.teal.shade700,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  String _getButtonText() {
    switch (_appState) {
      case AppState.loadingModel:
        return 'Loading Model...';
      case AppState.analyzing:
        return 'Analyzing...';
      default:
        return 'Identify Breed';
    }
  }
}