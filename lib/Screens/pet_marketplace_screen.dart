import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petcare/Screens/upload_pet_ads_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';

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
      appBar: AppBar(title: Text("Pet Marketplace")),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search pets by breed or category...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchQuery = value.trim()),
            ),
          ),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["all", "sale", "adoption", "sitting"].map((category) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(category.toUpperCase()),
                    selected: selectedCategory == category,
                    onSelected: (_) => setState(() => selectedCategory = category),
                  ),
                );
              }).toList(),
            ),
          ),

          // Ads List
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
                      margin: EdgeInsets.all(8),
                      child: ListTile(
                        leading: data['imageUrl'] != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(data['imageUrl']),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Icon(Icons.pets, size: 40),

                        title: Text("${data['breed'] ?? 'Unknown Breed'} (${data['category']?.toUpperCase() ?? 'N/A'})"),
                        subtitle: Text(
                          "Age: ${data['age'] ?? 'N/A'}\n"
                              "Health: ${data['healthStatus'] ?? 'N/A'}\n"
                              "Price: ${data['price']?.toString() ?? 'N/A'}",
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadPetAdScreen()),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
        tooltip: 'Post New Ad',
      ),
    );
  }
}
