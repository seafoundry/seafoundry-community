// @tier: community
import 'tiered_field_config_loader_stub.dart'
    if (dart.library.io) 'tiered_field_config_loader_io.dart';

Future<String?> loadTierFieldConfigFromDisk() =>
    loadTierFieldConfigFromDiskImpl();
