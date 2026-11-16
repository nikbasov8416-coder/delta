abstract interface class DeviceAuthenticator {
  Future<bool> available();
  Future<bool> authenticate();
}
