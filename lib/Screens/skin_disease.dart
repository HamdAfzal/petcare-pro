import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib;
import 'dart:typed_data';

class DiseaseIdentificationScreen extends StatefulWidget {
  const DiseaseIdentificationScreen({super.key});

  @override
  State<DiseaseIdentificationScreen> createState() => _DiseaseIdentificationScreenState();
}

class _DiseaseIdentificationScreenState extends State<DiseaseIdentificationScreen> {
  static const String MODEL_PATH = 'assets/skin_disease_classifier_balanced.tflite';
  static const int INPUT_SIZE = 224;
  static const List<String> CLASS_NAMES = [
    'Dermatitis',
    'Fungal_infections',
    'Healthy',
    'Hypersensitivity',
    'demodicosis',
    'ringworm'
  ];

  // State Variables
  Interpreter? _interpreter;
  File? _imageFile;
  String? _diseaseResult;
  double? _confidence;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      // Load model from assets folder using tflite_flutter
      _interpreter = await Interpreter.fromAsset(MODEL_PATH);
      print("TFLite Model loaded successfully.");
      setState(() {});
    } catch (e) {
      print("Failed to load model: $e");
      _showSnackbar('Failed to load model. Check assets and pubspec.yaml.');
    }
  }

  // New function to handle both Camera and Gallery selection
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _diseaseResult = null;
        _confidence = null;
      });
      // Immediately run prediction after picking a new image
      // _identifyDisease();
    }
  }

  // Dialog to ask user for image source (Camera or Gallery)
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.deepOrange),
                title: const Text('Photo Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepOrange),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _identifyDisease() async {
    if (_interpreter == null) {
      _showSnackbar('Model not loaded yet. Please wait.');
      return;
    }
    if (_imageFile == null) {
      _showSnackbar('Please select an image first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _diseaseResult = "Analyzing...";
    });

    try {
      // 1. Load, Decode, and Resize Image
      final imageBytes = await _imageFile!.readAsBytes();
      final originalImage = img_lib.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception("Failed to decode image.");
      }

      // Resize image to 224x224 (INPUT_SIZE)
      final resizedImage = img_lib.copyResize(originalImage, width: INPUT_SIZE, height: INPUT_SIZE);

      // 2. Prepare Input Tensor (1x224x224x3 float32, normalized)
      final inputBytes = Float32List(1 * INPUT_SIZE * INPUT_SIZE * 3);
      int pixelIndex = 0;

      for (var y = 0; y < INPUT_SIZE; y++) {
        for (var x = 0; x < INPUT_SIZE; x++) {
          final pixel = resizedImage.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;

          // Normalize to 0.0 - 1.0 (assuming Rescaling(1./255) during training)
          inputBytes[pixelIndex++] = r / 255.0;
          inputBytes[pixelIndex++] = g / 255.0;
          inputBytes[pixelIndex++] = b / 255.0;
        }
      }

      // Reshape the flat buffer into the required 1x224x224x3 tensor shape
      final inputTensor = inputBytes.reshape([1, INPUT_SIZE, INPUT_SIZE, 3]);

      // 3. Prepare Output Structure (1x6 float32) - Safest method for tflite_flutter
      final output = [List<double>.filled(CLASS_NAMES.length, 0.0)];

      // 4. Run Inference
      _interpreter!.run(inputTensor, output);

      // 5. Process Output
      final resultsBuffer = output[0];
      final bestPrediction = _processOutput(resultsBuffer);

      setState(() {
        _isProcessing = false;
        _diseaseResult = bestPrediction['label'];
        _confidence = bestPrediction['confidence'];
      });

    } catch (e) {
      print("Prediction error: $e");
      setState(() {
        _isProcessing = false;
        _diseaseResult = "Error during prediction.";
        _confidence = null;
      });
      _showSnackbar('Prediction failed. Ensure model and input shape are correct.');
    }
  }

  Map<String, dynamic> _processOutput(List<double> output) {
    int maxIndex = 0;
    double maxConfidence = 0.0;

    for (int i = 0; i < output.length; i++) {
      if (output[i] > maxConfidence) {
        maxConfidence = output[i];
        maxIndex = i;
      }
    }

    return {
      'label': CLASS_NAMES[maxIndex],
      'confidence': maxConfidence * 100,
    };
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool modelReady = _interpreter != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Skin Disease Identifier"),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Upload a skin lesion image for AI analysis.",
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),

              // Image Display Area
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepOrange.shade100, width: 2),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _imageFile!,
                    fit: BoxFit.cover,
                  ),
                )
                    : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera_back, size: 60, color: Colors.deepOrange.shade300),
                      const SizedBox(height: 8),
                      Text(
                        modelReady ? "Tap 'Select/Take Image' to begin" : "Model Loading...",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Image Selection Button
              ElevatedButton.icon(
                onPressed: modelReady ? _showImageSourceDialog : null,
                icon: const Icon(Icons.photo_album),
                label: const Text("Select or Take Image"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),

              // Identification Button
              ElevatedButton.icon(
                onPressed: (modelReady && _imageFile != null && !_isProcessing)
                    ? _identifyDisease
                    : null,
                icon: _isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
                    : const Icon(Icons.medical_information),
                label: Text(
                  modelReady
                      ? (_isProcessing ? "Analyzing..." : "Identify Disease")
                      : "Loading Model...",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 30),

              // Prediction Result Area
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Diagnosis Result:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const Divider(),
                      if (_diseaseResult == null || _isProcessing)
                        Text(
                          _isProcessing ? "AI Analysis in Progress..." : "Awaiting image selection and analysis.",
                          style: TextStyle(color: Colors.grey[600]),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Predicted Disease:",
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                            Text(
                              _diseaseResult!,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                            ),
                            if (_confidence != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  "Confidence: ${_confidence!.toStringAsFixed(2)}%",
                                  style: const TextStyle(fontSize: 16, color: Colors.teal),
                                ),
                              ),
                            const SizedBox(height: 10),
                            const Text(
                              "*Disclaimer: This is an AI prediction and should not replace professional medical advice.",
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.red),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}