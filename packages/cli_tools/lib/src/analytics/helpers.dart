import 'dart:io';

String getPlatformString() {
  if (Platform.isMacOS) {
    return 'MacOS';
  } else if (Platform.isWindows) {
    return 'Windows';
  } else if (Platform.isLinux) {
    return 'Linux';
  } else {
    return 'Unknown';
  }
}
