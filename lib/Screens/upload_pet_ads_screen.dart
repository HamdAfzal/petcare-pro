import 'dart:io';
import 'package:flutter/material.dart';
import 'package:petcare/Services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        imageUrl: base64Image,
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
    const primaryColor = Color(0xFF00BF8F);
    const backgroundColor = Color(0xFF001510);
    const textColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Post Pet Ad"),
        backgroundColor: primaryColor,
        foregroundColor: textColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildDropdownField(primaryColor, textColor),
              _buildTextField(_breedController, 'Breed', textColor),
              _buildTextField(_ageController, 'Age (in months)', textColor, keyboardType: TextInputType.number),
              if (_selectedCategory == 'sale')
                _buildTextField(_priceController, 'Price', textColor, keyboardType: TextInputType.number),
              _buildTextField(_healthController, 'Health Info', textColor),
              _buildTextField(_contactController, 'WhatsApp Number', textColor,
                  keyboardType: TextInputType.phone, validatorText: 'Enter WhatsApp number'),

              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Pick Image"),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: textColor),
              ),
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_selectedImage!.path), height: 150, fit: BoxFit.cover),
                  ),
                ),

              const SizedBox(height: 20),
              _isUploading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : ElevatedButton(
                onPressed: _submitAd,
                child: const Text('Post Ad'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  auth.signOut();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('isLoggedIn');
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      Color textColor, {
        TextInputType keyboardType = TextInputType.text,
        String? validatorText,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: textColor),
        keyboardType: keyboardType,
        validator: (value) => (validatorText ?? 'Enter $label').isNotEmpty && value!.isEmpty ? validatorText ?? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
          filled: true,
          fillColor: Colors.white10,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00BF8F)),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(Color primaryColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        dropdownColor: const Color(0xFF002620),
        iconEnabledColor: Colors.white,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: 'Category',
          labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
          filled: true,
          fillColor: Colors.white10,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primaryColor),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        items: ['sale', 'adoption', 'sitting']
            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: TextStyle(color: textColor))))
            .toList(),
        onChanged: (val) => setState(() => _selectedCategory = val!),
      ),
    );
  }
}
