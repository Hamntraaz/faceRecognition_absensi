import 'package:geolocator/geolocator.dart';

class LocationService {
  static const double kantorLat = -6.7915097; // Ganti koordinat kantor
  static const double kantorLong = 107.2773119;

  Future<bool> isWithinRadius() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    double distance = Geolocator.distanceBetween(
        position.latitude, position.longitude, kantorLat, kantorLong);
    return distance <= 50; // Radius 50 meter
  }
}