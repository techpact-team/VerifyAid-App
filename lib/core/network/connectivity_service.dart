import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  Future<bool> hasInternet() async {
    final results = await Connectivity().checkConnectivity();

    return !results.contains(ConnectivityResult.none);
  }
}
