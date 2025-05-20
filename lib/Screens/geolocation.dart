import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:petcare/Services/colors.dart';  // Import your color class

class GeolocationScreen extends StatefulWidget {
  @override
  _GeolocationScreenState createState() => _GeolocationScreenState();
}

class _GeolocationScreenState extends State<GeolocationScreen> {
  Position? _userPosition;
  bool _isLoading = true;
  List<Map<String, dynamic>> _locations = [];
  String? _selectedService;
  final String _foursquareApiKey = 'fsq356baYR+sJ0rxJ4zgjnNGZdBQidrSrjHKALzEqNigoPY=';

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _userPosition = position;
      _isLoading = false;
    });
  }

  Future<void> _fetchNearbyPlaces(String serviceType) async {
    if (_userPosition == null) return;

    setState(() {
      _isLoading = true;
      _locations = [];
    });

    double lat = _userPosition!.latitude;
    double lon = _userPosition!.longitude;

    String query;
    switch (serviceType) {
      case 'Pet Shop':
        query = 'pet shop';
        break;
      case 'Veterinary':
        query = 'veterinary';
        break;
      case 'Grooming':
        query = 'pet grooming';
        break;
      default:
        query = '';
    }

    final url = Uri.parse(
      'https://api.foursquare.com/v3/places/search?query=${Uri.encodeComponent(query)}&ll=$lat,$lon&radius=10000&limit=20',
    );

    try {
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': _foursquareApiKey,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'];

        List<Map<String, dynamic>> fetchedLocations = results.map((place) {
          return {
            "name": place['name'] ?? 'Unnamed',
            "lat": place['geocodes']['main']['latitude'],
            "lon": place['geocodes']['main']['longitude'],
            "address": place['location']['formatted_address'] ?? '',
          };
        }).toList();

        setState(() {
          _locations = fetchedLocations;
          _isLoading = false;
        });
      } else {
        print('Error fetching places: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Exception fetching places: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openInGoogleMaps(String query) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Pet Care Services'),
        backgroundColor: AppColors.primaryColor, // Using primaryColor from AppColors
        elevation: 0, // Make the AppBar flat
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
        child: _isLoading && _userPosition == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Material(
                elevation: 5, // Shadow effect for the dropdown
                borderRadius: BorderRadius.circular(10),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    labelText: 'Select Service Type',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: _selectedService,
                  items: ["Pet Shop", "Veterinary", "Grooming"]
                      .map((service) => DropdownMenuItem<String>(
                    value: service,
                    child: Text(service),
                  ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedService = value);
                      _fetchNearbyPlaces(value);
                    }
                  },
                ),
              ),
            ),
            if (_userPosition != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        center: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                        zoom: 13.0,
                        interactiveFlags: InteractiveFlag.none,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                          subdomains: ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                              builder: (ctx) => const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _locations.isEmpty
                  ? Center(
                child: Text(
                  _selectedService == null
                      ? 'Please select a service type above'
                      : 'No nearby $_selectedService found',
                  style: const TextStyle(fontSize: 16),
                ),
              )
                  : ListView.builder(
                itemCount: _locations.length,
                itemBuilder: (context, index) {
                  final place = _locations[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4, // Adding shadow to the card
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Text(
                          place['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(place['address']),
                        trailing: const Icon(Icons.directions, color: Colors.teal),
                        onTap: () => _openInGoogleMaps(place['name']),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
