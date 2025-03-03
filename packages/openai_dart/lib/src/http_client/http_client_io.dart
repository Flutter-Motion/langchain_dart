import 'package:http/retry.dart';

import 'http_client_with_cupertino.dart' as http;

/// Creates an IOClient with a retry policy.
http.Client createDefaultHttpClient() {
  return RetryClient(http.getClient());
}

/// Middleware for HTTP requests.
Future<http.BaseRequest> onRequestHandler(final http.BaseRequest request) {
  return Future.value(request);
}
