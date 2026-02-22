/// Web library for flutter_secure_storage
library flutter_secure_storage_web;

export 'src/flutter_secure_storage_web_stub.dart'
    if (dart.library.html) 'src/flutter_secure_storage_web_html.dart';
