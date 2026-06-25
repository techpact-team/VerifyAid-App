import 'package:connectivity_plus/connectivity_plus.dart';


class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  /// Static method — call directly as ConnectivityService.hasInternetConnection().
  static Future<bool> hasInternetConnection() async {
    final results = await _connectivity.checkConnectivity();

    if (results.isEmpty) {
      return false;
    }

    return results.any((result) {
      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn;
    });
  }
}