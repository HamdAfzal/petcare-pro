import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petcare/Screens/upload_pet_ads_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';

// Import the AppColors class from your colors.dart file
import 'package:petcare/Services/colors.dart';  // Adjust the path as necessary

class PetMarketplaceScreen extends StatefulWidget {
  @override
  _PetMarketplaceScreenState createState() => _PetMarketplaceScreenState();
}

class _PetMarketplaceScreenState extends State<PetMarketplaceScreen> {
  String selectedCategory = "all"; // all, sale, adoption, sitting
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pet Marketplace"),
        backgroundColor: AppColors.primaryColor, // Using primaryColor for the AppBar
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryColor,
              AppColors.secondaryColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Search Box with white background and shadow effect
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Material(
                elevation: 5, // Adding elevation to the Material widget for shadow effect
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search pets by breed or category...',
                    hintStyle: TextStyle(color: Colors.grey), // Optional: Change hint text color
                    prefixIcon: Icon(Icons.search, color: Colors.black), // Search icon color
                    filled: true,
                    fillColor: Colors.white, // White background for the search box
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), // Rounded corners
                      borderSide: BorderSide.none, // No border
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value.trim()),
                ),
              ),
            ),

            // Category Filter Chips with color and elevation effect
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["all", "sale", "adoption", "sitting"].map((category) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: ChoiceChip(
                      label: Text(category.toUpperCase(), style: TextStyle(color: Colors.white)),
                      selected: selectedCategory == category,
                      selectedColor: AppColors.secondaryColor,
                      backgroundColor: AppColors.primaryColor,
                      onSelected: (_) => setState(() => selectedCategory = category),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Ads List with enhanced cards
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('marketplace_ads')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                  // Filter ads based on selected category and search query
                  final filteredAds = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final categoryMatch = selectedCategory == "all" || data['category'] == selectedCategory;
                    final searchLower = searchQuery.toLowerCase();
                    final matchesSearch = searchQuery.isEmpty ||
                        (data['breed']?.toLowerCase().contains(searchLower) ?? false) ||
                        (data['category']?.toLowerCase().contains(searchLower) ?? false);
                    return categoryMatch && matchesSearch;
                  }).toList();

                  if (filteredAds.isEmpty) {
                    return Center(child: Text("No ads found."));
                  }

                  return ListView.builder(
                    itemCount: filteredAds.length,
                    itemBuilder: (context, index) {
                      final data = filteredAds[index].data() as Map<String, dynamic>;

                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 5, // Card shadow
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: data['imageUrl'] != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(data['imageUrl']),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          )
                              : Icon(Icons.pets, size: 40, color: AppColors.primaryColor),

                          title: Text("${data['breed'] ?? 'Unknown Breed'} (${data['category']?.toUpperCase() ?? 'N/A'})",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            "Age: ${data['age'] ?? 'N/A'}\n"
                                "Health: ${data['healthStatus'] ?? 'N/A'}\n"
                                "Price: ${data['price']?.toString() ?? 'N/A'}",
                            style: TextStyle(color: Colors.black54),
                          ),
                          trailing: IconButton(
                            icon: Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                            onPressed: () {
                              final contactNumber = data['contactNumber'] ?? '';
                              if (contactNumber.isNotEmpty) {
                                launchUrl(Uri.parse("https://wa.me/$contactNumber"));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("No contact number provided")),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadPetAdScreen()),
          );
        },
        backgroundColor: AppColors.primaryColor, // Customized FAB background color
        child: const Icon(Icons.add),
        tooltip: 'Post New Ad',
        elevation: 10, // Elevated FAB to give it prominence
      ),
    );
  }
}
