// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/services/physical_form_registry.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

/// Service for managing physical form configuration versions
///
/// Versions are stored in Firestore to maintain snapshot integrity.
/// When configuration changes, a new version is created and new records
/// reference the new version, while old records continue using their
/// original version for accurate historical snapshots.
class PhysicalFormVersionService {
  PhysicalFormVersionService({
    required FirebaseFirestore firestore,
    FirestoreCollectionResolver? resolver,
  }) : _firestore = firestore,
       _resolver = resolver ?? FirestoreCollectionResolver.instance;

  final FirebaseFirestore _firestore;
  final FirestoreCollectionResolver _resolver;

  static const String _collectionName = 'physical_form_config_versions';

  /// Get reference to versions collection
  CollectionReference<Map<String, dynamic>> get _collection =>
      _resolver.collection(_firestore, _collectionName);

  /// Get the current active version ID
  Future<String> getCurrentVersion() async {
    // Query for the most recent version
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      // No versions exist yet - create initial version from current YAML
      return await _createInitialVersion();
    }

    return snapshot.docs.first.id;
  }

  /// Create initial version from current YAML configuration
  Future<String> _createInitialVersion() async {
    // Get all configured organisms and their data
    final yamlContent = <String, dynamic>{};

    yamlContent['version'] = 'v1';
    yamlContent['created_at'] = DateTime.now().toIso8601String();
    yamlContent['created_by'] = 'system';

    // This is a simplified initial version - in practice, we'd read the full YAML
    // For now, we'll just store a reference that v1 exists

    final version = PhysicalFormConfigVersion(
      id: 'v1',
      createdAt: DateTime.now(),
      createdBy: 'system',
      yamlContent: yamlContent,
    );

    await _saveVersion(version);
    return version.id;
  }

  /// Save a configuration version to Firestore
  Future<void> _saveVersion(PhysicalFormConfigVersion version) async {
    await _collection.doc(version.id).set(version.toJson());
  }

  /// Load a specific version from Firestore
  Future<PhysicalFormConfigVersion?> getVersion(String versionId) async {
    final doc = await _collection.doc(versionId).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();
    if (data == null) {
      return null;
    }

    return PhysicalFormConfigVersion.fromJson(data);
  }

  /// Create a new version from current configuration
  ///
  /// This should be called when admin users make changes to the configuration.
  /// Returns the new version ID.
  Future<String> createNewVersion({
    required String userId,
    required Map<String, dynamic> yamlContent,
  }) async {
    // Get current version to determine next version number
    final currentVersion = await getCurrentVersion();
    final currentNum = int.tryParse(currentVersion.substring(1)) ?? 1;
    final newVersionId = 'v${currentNum + 1}';

    final version = PhysicalFormConfigVersion(
      id: newVersionId,
      createdAt: DateTime.now(),
      createdBy: userId,
      yamlContent: yamlContent,
    );

    await _saveVersion(version);

    // Clear registry cache to pick up new version
    PhysicalFormRegistry.instance.clearCache();

    return newVersionId;
  }

  /// Get all versions ordered by creation date (newest first)
  Future<List<PhysicalFormConfigVersion>> getAllVersions() async {
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => PhysicalFormConfigVersion.fromJson(doc.data()))
        .toList();
  }

  /// Check if a version exists
  Future<bool> versionExists(String versionId) async {
    final doc = await _collection.doc(versionId).get();
    return doc.exists;
  }

  /// Get version metadata without full YAML content
  Future<Map<String, dynamic>?> getVersionMetadata(String versionId) async {
    final doc = await _collection.doc(versionId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final data = doc.data()!;
    return {
      'id': data['id'],
      'createdAt': data['createdAt'],
      'createdBy': data['createdBy'],
    };
  }
}
