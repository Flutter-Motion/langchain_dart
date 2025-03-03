import 'dart:convert';
import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

export 'package:http/http.dart'
    show
        BaseRequest,
        Client,
        ClientException,
        MultipartFile,
        MultipartRequest,
        Request,
        Response,
        StreamedResponse;

/// Returns an instance of the `http.Client` class.
/// On iOS and macOS, it returns an instance of the `CupertinoClient` class.
http.Client getClient() {
  http.Client client;
  if (Platform.isIOS || Platform.isMacOS) {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration()
      ..cache = URLCache.withCapacity(memoryCapacity: 2 * 1024 * 1024);
    client = CupertinoClient.fromSessionConfiguration(config);
  } else {
    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    httpClient.maxConnectionsPerHost = 20;

    client = IOClient(httpClient);
  }
  return client;
}
