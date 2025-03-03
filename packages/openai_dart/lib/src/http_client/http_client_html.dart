import 'package:fetch_client/fetch_client.dart' as fetch;
import 'package:http/retry.dart';

import 'http_client_with_cupertino.dart' as http;

/// Creates an IOClient with a retry policy.
http.Client createDefaultHttpClient() {
  return RetryClient(fetch.FetchClient(mode: fetch.RequestMode.cors));
}

/// Middleware for HTTP requests.
Future<http.BaseRequest> onRequestHandler(final http.BaseRequest request) {
  // If the request if bigger than 60KiB set persistentConnection to false
  // Ref: https://github.com/Zekfad/fetch_client#large-payload
  if ((request.contentLength ?? 0) > 61440) {
    request.persistentConnection = false;
  }
  return Future.value(request);
}
