import 'package:flutter/material.dart';
import 'package:petcare/Screens/geolocation.dart';
import 'package:petcare/Screens/pet_marketplace_screen.dart';
import 'package:petcare/Screens/signup_page.dart';
import 'package:petcare/Screens/upload_pet_ads_screen.dart';

import '../Screens/login_page.dart';

class Routes {
  static const String signup = '/signup';
  static const String marketplace = '/marketplace';
  static const String login = '/login';
  static const String upload = '/upload';
  static const String geolocation = '/geolocation';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => LoginPage(),
    signup: (context) => SignUpPage(),
    marketplace: (context) => PetMarketplaceScreen(),
    upload: (context) => UploadPetAdScreen(),
    geolocation: (context) => GeolocationScreen(),
  };
}
