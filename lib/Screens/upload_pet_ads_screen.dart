import 'dart:io';
import 'package:flutter/material.dart';
import 'package:petcare/Services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:petcare/Providers/marketplace_ad_provider.dart';
import '../models/marketplace_ad_model.dart';

class UploadPetAdScreen extends StatefulWidget {
  const UploadPetAdScreen({super.key});

  @override
  State<UploadPetAdScreen> createState() => _UploadAdScreenState();
}

class _UploadAdScreenState extends State<UploadPetAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _priceController = TextEditingController();
  final _healthController = TextEditingController();
  final _contactController = TextEditingController();

  String _selectedCategory = 'sale';
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
AuthService auth = AuthService();
  Future<String> _convertImageToBase64(XFile imageFile) async {
    final bytes = await File(imageFile.path).readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate() || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select an image')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      final base64Image = await _convertImageToBase64(_selectedImage!);

      final ad = MarketplaceAd(
        id: const Uuid().v4(),
        userId: user.uid,
        category: _selectedCategory,
        breed: _breedController.text,
        age: int.parse(_ageController.text),
        price: _selectedCategory == 'sale' ? _priceController.text : '',
        healthStatus: _healthController.text,
        imageUrl: base64Image, // Store base64 string here
        contactNumber: _contactController.text,
        createdAt: Timestamp.now(),
      );

      await Provider.of<MarketplaceAdProvider>(context, listen: false).postAd(ad);

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = picked);
    }
  }

  @override
  void dispose() {
    _breedController.dispose();
    _ageController.dispose();
    _priceController.dispose();
    _healthController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post Pet Ad")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: ['sale', 'adoption', 'sitting']
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(labelText: 'Breed'),
                validator: (value) => value!.isEmpty ? 'Enter breed' : null,
              ),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age (in months)'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Enter age' : null,
              ),
              if (_selectedCategory == 'sale')
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
              TextFormField(
                controller: _healthController,
                decoration: const InputDecoration(labelText: 'Health Info'),
              ),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'WhatsApp Number'),
                validator: (value) => value!.isEmpty ? 'Enter WhatsApp number' : null,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Pick Image"),
              ),
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Image.file(File(_selectedImage!.path), height: 150),
                ),

              const SizedBox(height: 20),
              _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _submitAd,
                child: const Text('Post Ad'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  auth.signOut();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('isLoggedIn'); // or prefs.setBool('isLoggedIn', false);
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
