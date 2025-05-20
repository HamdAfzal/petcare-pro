import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petcare/Services/auth_service.dart';
import '../Services/colors.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  final AuthService auth = AuthService();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryColor,
              AppColors.secondaryColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.08,
              vertical: size.height * 0.05,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),

                  // Page Title
                  Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // First Name Input
                  _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),

                  // Last Name Input
                  _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  // Email Input
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  _buildPasswordField(
                    controller: _passwordController,
                    label: 'Password',
                    isConfirm: false,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Input
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    isConfirm: true,
                    validator: (value) =>
                    value != _passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 30),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5, // Add shadow effect
                      ),
                      child: const Text('Register'),
                    ),
                  ),

                  // Social Button / SignUp Options
                  const SizedBox(height: 30),
                  const Center(child: Text("or continue with", style: TextStyle(color: Colors.white))),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _socialButton('assets/google.png'),
                    ],
                  ),
                  const SizedBox(height: 35),

                  // Already have account text
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text(
                        "Already have an account? Login",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      final name = "${_firstNameController.text} ${_lastNameController.text}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registering $name...')),
      );

      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Send verification email
        await userCredential.user?.sendEmailVerification();
        print("Verification email sent!");
        if (userCredential.user != null && userCredential.user!.emailVerified) {
          print("Login successful, email verified!");
        } else {
          print("Email not verified. Please check your inbox.");
          await FirebaseAuth.instance.signOut();
        }
        // Show confirmation dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Success"),
              content: const Text("Account created successfully!"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      } catch (e) {
        setState(() {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white),
      prefixIcon: Icon(icon, color: Colors.white),
      filled: true,
      fillColor: Colors.white.withOpacity(0.2),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label, icon),
      validator: (value) =>
      value == null || value.isEmpty ? 'Enter $label' : null,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isConfirm,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isConfirm ? !_showConfirmPassword : !_showPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: const Icon(Icons.lock, color: Colors.white),
        suffixIcon: IconButton(
          icon: Icon(
            (isConfirm ? _showConfirmPassword : _showPassword)
                ? Icons.visibility
                : Icons.visibility_off,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              if (isConfirm) {
                _showConfirmPassword = !_showConfirmPassword;
              } else {
                _showPassword = !_showPassword;
              }
            });
          },
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator ??
              (value) =>
          value == null || value.length < 6 ? 'Minimum 6 characters' : null,
    );
  }

  Widget _socialButton(String assetPath) {
    return GestureDetector(
      onTap: () async {
        final user = await AuthService().signInWithGoogle();
        if (user != null) {
          Navigator.pushReplacementNamed(context, '/marketplace');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google sign-in failed')),
          );
        }
      },
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }
}
