// @tier: community
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/connectivity_service.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/offline_queue.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage;
  final _logger = LoggingService.instance;

  ImageService({FirebaseService? firebaseService, FirebaseStorage? storage})
    : assert(
        firebaseService != null || storage != null,
        'ImageService requires either a FirebaseService or FirebaseStorage instance',
      ),
      _storage = storage ?? firebaseService!.storage;

  Future<fbAuth.User?> ensureAuthenticated({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final auth = fbAuth.FirebaseAuth.instance;
    var user = auth.currentUser;
    if (user != null) {
      await _refreshAuthToken(user);
      return user;
    }
    try {
      user = await auth
          .authStateChanges()
          .firstWhere((candidate) => candidate != null)
          .timeout(timeout);
    } catch (error) {
      _logger.warning('No Firebase auth user available for image upload', error);
      return null;
    }
    if (user != null) {
      await _refreshAuthToken(user);
    }
    return user;
  }

  Future<void> _refreshAuthToken(fbAuth.User user) async {
    try {
      await user.getIdToken(true);
    } catch (error) {
      _logger.warning('Failed to refresh Firebase auth token', error);
    }
  }

  /// Resolve the storage key for organization uploads.
  /// Only organization IDs are accepted (no domain fallback).
  static String resolveOrganizationStorageKey({String? organizationId}) {
    final id = (organizationId ?? '').trim();
    return id.isNotEmpty && id != Missing.string ? id : Missing.string;
  }

  static String resolveOrganizationStorageKeyFromOrganization(
    Organization organization,
  ) {
    return resolveOrganizationStorageKey(
      organizationId: organization.id,
    );
  }

  /// Checks if the app is running on iOS Simulator
  static bool _isIOSSimulator() {
    if (kIsWeb || !Platform.isIOS) return false;

    // Check for simulator environment variable
    final simulatorDevice = Platform.environment['SIMULATOR_DEVICE_NAME'];
    return simulatorDevice != null && simulatorDevice.isNotEmpty;
  }

  /// Gets the camera permission status.
  /// Returns [PermissionStatus.granted] on web (camera handled by browser).
  /// Returns [PermissionStatus.permanentlyDenied] on iOS Simulator.
  Future<PermissionStatus> getCameraPermissionStatus() async {
    if (kIsWeb) {
      return PermissionStatus.granted;
    }
    if (_isIOSSimulator()) {
      _logger.info(
        'iOS Simulator detected - returning permanentlyDenied status',
      );
      return PermissionStatus.permanentlyDenied;
    }
    return await Permission.camera.status;
  }

  /// Requests camera permission.
  /// Returns [PermissionStatus.granted] on web (camera handled by browser).
  /// Returns [PermissionStatus.permanentlyDenied] on iOS Simulator.
  Future<PermissionStatus> requestCameraPermission() async {
    if (kIsWeb) {
      return PermissionStatus.granted;
    }
    if (_isIOSSimulator()) {
      _logger.info(
        'iOS Simulator detected - returning permanentlyDenied status',
      );
      return PermissionStatus.permanentlyDenied;
    }
    return await Permission.camera.request();
  }

  /// Captures an image from the camera
  Future<File?> captureImage() async {
    try {
      if (!kIsWeb) {
        // Check camera permission (handles simulator internally)
        final permissionStatus = await requestCameraPermission();
        if (!permissionStatus.isGranted) {
          _logger.warning(
            'Camera permission not granted: ${permissionStatus.name}',
          );
          return null;
        }
      }

      // Capture image from camera
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Compress to 85% quality
        maxWidth: 1920, // Max width for reasonable file size
      );

      if (image == null) {
        return null;
      }

      return File(image.path);
    } catch (e) {
      _logger.error('Error capturing image', e);
      return null;
    }
  }

  /// Picks an image file from the device (supports JPEG, PNG, TIFF).
  ///
  /// Returns the selected file, or null if cancelled or an error occurs.
  /// **Web**: [PlatformFile.path] is null on web, so this method returns null.
  /// Use [pickImageBytes] instead for cross-platform image picking.
  Future<File?> pickImageFile({
    List<String>? allowedExtensions,
  }) async {
    if (kIsWeb) {
      _logger.warning(
        'pickImageFile is not supported on web. Use pickImageBytes instead.',
      );
      return null;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ??
            ['jpg', 'jpeg', 'png', 'tiff', 'tif'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled
      }

      final file = result.files.first;
      if (file.path == null) {
        _logger.warning('File picker returned null path');
        return null;
      }

      final selectedFile = File(file.path!);

      // Validate file exists and is readable
      if (!await selectedFile.exists()) {
        _logger.warning('Selected file does not exist: ${file.path}');
        return null;
      }

      // Check file size (warn if > 100MB)
      _warnIfLargeFile(await selectedFile.length());

      return selectedFile;
    } catch (e) {
      _logger.error('Error picking image file', e);
      return null;
    }
  }

  /// Picks an image and returns its bytes. Works on all platforms (web + native).
  ///
  /// Returns a [PickedImageData] with the bytes and filename, or null if
  /// cancelled or an error occurs.
  Future<PickedImageData?> pickImageBytes({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ??
            ['jpg', 'jpeg', 'png', 'tiff', 'tif'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _logger.warning('File picker returned null bytes for: ${file.name}');
        return null;
      }

      _warnIfLargeFile(bytes.length);

      return PickedImageData(bytes: bytes, name: file.name);
    } catch (e) {
      _logger.error('Error picking image bytes', e);
      return null;
    }
  }

  /// Picks multiple image files from the device (supports JPEG, PNG, TIFF).
  ///
  /// Returns a list of selected files. Filters out invalid files and logs
  /// warnings for files that cannot be read. Not supported on web.
  Future<List<File>> pickImageFiles({
    List<String>? allowedExtensions,
  }) async {
    if (kIsWeb) {
      _logger.warning(
        'pickImageFiles is not supported on web.',
      );
      return [];
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ??
            ['jpg', 'jpeg', 'png', 'tiff', 'tif'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final validFiles = <File>[];
      for (final file in result.files) {
        if (file.path == null) {
          _logger.warning(
            'File picker returned null path for file: ${file.name}',
          );
          continue;
        }

        final selectedFile = File(file.path!);
        if (!await selectedFile.exists()) {
          _logger.warning('Selected file does not exist: ${file.path}');
          continue;
        }

        validFiles.add(selectedFile);
      }

      return validFiles;
    } catch (e) {
      _logger.error('Error picking image files', e);
      return [];
    }
  }

  void _warnIfLargeFile(int fileSize) {
    const maxSize = 100 * 1024 * 1024; // 100MB
    if (fileSize > maxSize) {
      _logger.warning(
        'Selected file is very large '
        '(${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). '
        'Upload may be slow or fail.',
      );
    }
  }

  /// Determines content type from file extension
  String _getContentType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'tiff':
      case 'tif':
        return 'image/tiff';
      default:
        return 'image/jpeg'; // Default fallback
    }
  }

  /// Gets file extension from path
  String _getFileExtension(String filePath) {
    return filePath.toLowerCase().split('.').last;
  }

  String _requireOrganizationStorageKey(
    String organizationId, {
    String? operation,
  }) {
    final normalized = organizationId.trim();
    if (normalized.isEmpty || normalized == Missing.string) {
      final message = [
        'Organization ID is required to upload images.',
        'Please reload and try again.',
        if (operation != null) '(operation: $operation)',
      ].join(' ');
      _logger.error(message);
      throw ImageUploadException(message);
    }
    return normalized;
  }

  String _requireUserStorageKey(
    String userId, {
    String? operation,
  }) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      final message = [
        'User ID is required to upload profile images.',
        'Please reload and try again.',
        if (operation != null) '(operation: $operation)',
      ].join(' ');
      _logger.error(message);
      throw ImageUploadException(message);
    }
    return normalized;
  }

  SettableMetadata _buildStorageMetadata({
    required String contentType,
    required String organizationId,
    required String recordType,
    required String recordId,
    required String originalFileName,
    String? uploadedById,
    Map<String, String>? extraCustomMetadata,
  }) {
    final metadata = <String, String>{
      'organizationId': organizationId,
      // Keep legacy key for compatibility with existing tooling.
      'organizationDomain': organizationId,
      'recordType': recordType,
      'recordId': recordId,
      if (uploadedById != null && uploadedById.isNotEmpty)
        'uploadedById': uploadedById,
      'uploadedAt': DateTime.now().toIso8601String(),
      'originalFileName': originalFileName,
    };
    if (extraCustomMetadata != null && extraCustomMetadata.isNotEmpty) {
      metadata.addAll(extraCustomMetadata);
    }
    return SettableMetadata(
      contentType: contentType,
      customMetadata: {
        ...metadata,
      },
    );
  }

  SettableMetadata _buildUserStorageMetadata({
    required String contentType,
    required String userId,
    String? organizationId,
    required String originalFileName,
  }) {
    return SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'userId': userId,
        if (organizationId != null && organizationId.isNotEmpty)
          'organizationId': organizationId,
        'recordType': 'userProfile',
        'uploadedAt': DateTime.now().toIso8601String(),
        'originalFileName': originalFileName,
      },
    );
  }

  String _buildStoragePath({
    required String organizationId,
    required String recordType,
    required String recordId,
    required String fileName,
  }) {
    return 'organizations/$organizationId/images/'
        '${recordType.trim()}/$recordId/$fileName';
  }

  String _buildUserStoragePath({
    required String userId,
    required String fileName,
  }) {
    return 'users/$userId/images/profile/$fileName';
  }

  Future<void> _logUploadAuthContext({
    required String storagePath,
    required String organizationId,
    required String recordType,
    required String recordId,
  }) async {
    if (!kDebugMode) {
      return;
    }

    try {
      final auth = fbAuth.FirebaseAuth.instance;
      final user = auth.currentUser;
      final appOptions = _storage.app.options;

      _logger.debug(
        '🔐 Storage upload context',
        {
          'storagePath': storagePath,
          'organizationId': organizationId,
          'recordType': recordType,
          'recordId': recordId,
          'projectId': appOptions.projectId,
          'storageBucket': appOptions.storageBucket,
          'authProjectId': auth.app.options.projectId,
          'authUserUid': user?.uid ?? 'null',
          'authUserEmail': user?.email ?? 'null',
          'authUserIsAnonymous': user?.isAnonymous ?? false,
        },
      );

      if (user == null) {
        _logger.debug('🔐 Storage upload auth token: no current user');
        return;
      }

      final tokenResult = await user.getIdTokenResult();
      _logger.debug(
        '🔐 Storage upload auth token',
        {
          'tokenPresent': tokenResult.token?.isNotEmpty ?? false,
          'issuedAt': tokenResult.issuedAtTime,
          'expiresAt': tokenResult.expirationTime,
          'signInProvider': tokenResult.signInProvider,
        },
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to log storage upload context', e);
      _logger.debug('Storage upload context log error', stackTrace);
    }
  }

  /// Waits for an upload task to complete, monitoring progress.
  ///
  /// The progress [StreamSubscription] is properly cancelled after the
  /// upload completes to avoid leaks.
  Future<String?> _awaitUploadTask({
    required UploadTask uploadTask,
    required String storagePath,
    void Function(double)? onProgress,
  }) async {
    StreamSubscription<TaskSnapshot>? progressSubscription;
    try {
      if (onProgress != null) {
        progressSubscription = uploadTask.snapshotEvents.listen(
          (TaskSnapshot snapshot) {
            if (snapshot.totalBytes > 0) {
              final progress =
                  snapshot.bytesTransferred / snapshot.totalBytes;
              onProgress(progress);
            }
          },
        );
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      _logger.info('Image uploaded successfully: $storagePath');
      return downloadUrl;
    } finally {
      await progressSubscription?.cancel();
    }
  }

  /// Uploads an image to Firebase Storage from a [File] (native only).
  ///
  /// Returns the download URL of the uploaded image, or null if upload fails.
  /// Supports JPEG, PNG, and TIFF formats.
  ///
  /// The image is stored at:
  /// `organizations/{organizationId}/images/{recordType}/{recordId}/{fileName}`
  ///
  /// [onProgress] callback receives progress as a double between 0.0 and 1.0.
  Future<String?> uploadImage({
    required File imageFile,
    required String organizationId,
    required String recordType,
    required String recordId,
    void Function(double)? onProgress,
    String? customFileName,
    String? uploadedById,
    Map<String, String>? extraCustomMetadata,
  }) async {
    try {
      final resolvedOrgId = _requireOrganizationStorageKey(
        organizationId,
        operation: 'uploadImage',
      );
      // Validate file exists
      if (!await imageFile.exists()) {
        _logger.error('Image file does not exist: ${imageFile.path}');
        return null;
      }

      // Generate unique filename preserving original extension
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(imageFile.path);
      final fileName = customFileName ?? '${timestamp}_$recordId.$extension';
      final storagePath = _buildStoragePath(
        organizationId: resolvedOrgId,
        recordType: recordType,
        recordId: recordId,
        fileName: fileName,
      );
      await _logUploadAuthContext(
        storagePath: storagePath,
        organizationId: resolvedOrgId,
        recordType: recordType,
        recordId: recordId,
      );

      final contentType = _getContentType(imageFile.path);
      final ref = _storage.ref().child(storagePath);

      final uploadTask = ref.putFile(
        imageFile,
        _buildStorageMetadata(
          contentType: contentType,
          organizationId: resolvedOrgId,
          recordType: recordType,
          recordId: recordId,
          originalFileName: imageFile.path.split('/').last,
          uploadedById: uploadedById,
          extraCustomMetadata: extraCustomMetadata,
        ),
      );

      return _awaitUploadTask(
        uploadTask: uploadTask,
        storagePath: storagePath,
        onProgress: onProgress,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading image: ${imageFile.path}',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Uploads image bytes to Firebase Storage (works on all platforms).
  ///
  /// Returns the download URL of the uploaded image, or null if upload fails.
  ///
  /// [onProgress] callback receives progress as a double between 0.0 and 1.0.
  Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String fileName,
    required String organizationId,
    required String recordType,
    required String recordId,
    void Function(double)? onProgress,
    String? uploadedById,
    Map<String, String>? extraCustomMetadata,
  }) async {
    try {
      final resolvedOrgId = _requireOrganizationStorageKey(
        organizationId,
        operation: 'uploadImageBytes',
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(fileName);
      final storedFileName = '${timestamp}_$recordId.$extension';
      final storagePath = _buildStoragePath(
        organizationId: resolvedOrgId,
        recordType: recordType,
        recordId: recordId,
        fileName: storedFileName,
      );
      await _logUploadAuthContext(
        storagePath: storagePath,
        organizationId: resolvedOrgId,
        recordType: recordType,
        recordId: recordId,
      );

      final contentType = _getContentType(fileName);
      final ref = _storage.ref().child(storagePath);

      final uploadTask = ref.putData(
        bytes,
        _buildStorageMetadata(
          contentType: contentType,
          organizationId: resolvedOrgId,
          recordType: recordType,
          recordId: recordId,
          originalFileName: fileName,
          uploadedById: uploadedById,
          extraCustomMetadata: extraCustomMetadata,
        ),
      );

      return _awaitUploadTask(
        uploadTask: uploadTask,
        storagePath: storagePath,
        onProgress: onProgress,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading image bytes: $fileName',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Uploads a user profile image to Firebase Storage (native only).
  ///
  /// Stored at: `users/{userId}/images/profile/{fileName}`
  Future<String?> uploadUserImage({
    required File imageFile,
    required String userId,
    String? organizationId,
    void Function(double)? onProgress,
    String? customFileName,
  }) async {
    try {
      final resolvedUserId = _requireUserStorageKey(
        userId,
        operation: 'uploadUserImage',
      );
      if (!await imageFile.exists()) {
        _logger.error('Image file does not exist: ${imageFile.path}');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(imageFile.path);
      final fileName = customFileName ?? '${timestamp}_$resolvedUserId.$extension';
      final storagePath = _buildUserStoragePath(
        userId: resolvedUserId,
        fileName: fileName,
      );

      await _logUploadAuthContext(
        storagePath: storagePath,
        organizationId: organizationId ?? Missing.string,
        recordType: 'userProfile',
        recordId: resolvedUserId,
      );

      final contentType = _getContentType(imageFile.path);
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(
        imageFile,
        _buildUserStorageMetadata(
          contentType: contentType,
          userId: resolvedUserId,
          organizationId: organizationId,
          originalFileName: imageFile.path.split('/').last,
        ),
      );

      return _awaitUploadTask(
        uploadTask: uploadTask,
        storagePath: storagePath,
        onProgress: onProgress,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading user image: ${imageFile.path}',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Uploads a user profile image to Firebase Storage from bytes.
  ///
  /// Stored at: `users/{userId}/images/profile/{fileName}`
  Future<String?> uploadUserImageBytes({
    required Uint8List bytes,
    required String fileName,
    required String userId,
    String? organizationId,
    void Function(double)? onProgress,
  }) async {
    try {
      final resolvedUserId = _requireUserStorageKey(
        userId,
        operation: 'uploadUserImageBytes',
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(fileName);
      final storedFileName = '${timestamp}_$resolvedUserId.$extension';
      final storagePath = _buildUserStoragePath(
        userId: resolvedUserId,
        fileName: storedFileName,
      );

      await _logUploadAuthContext(
        storagePath: storagePath,
        organizationId: organizationId ?? Missing.string,
        recordType: 'userProfile',
        recordId: resolvedUserId,
      );

      final contentType = _getContentType(fileName);
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putData(
        bytes,
        _buildUserStorageMetadata(
          contentType: contentType,
          userId: resolvedUserId,
          organizationId: organizationId,
          originalFileName: fileName,
        ),
      );

      return _awaitUploadTask(
        uploadTask: uploadTask,
        storagePath: storagePath,
        onProgress: onProgress,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error uploading user image bytes: $fileName',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Uploads multiple images to Firebase Storage
  /// Returns a list of download URLs
  Future<List<String>> uploadImages({
    required List<File> imageFiles,
    required String organizationId,
    required String recordType,
    required String recordId,
    void Function(int current, int total)? onProgress,
  }) async {
    final List<String> urls = [];
    final total = imageFiles.length;

    for (int i = 0; i < imageFiles.length; i++) {
      final url = await uploadImage(
        imageFile: imageFiles[i],
        organizationId: organizationId,
        recordType: recordType,
        recordId: recordId,
        onProgress: (_) {
          // Report progress for current file
          onProgress?.call(i + 1, total);
        },
      );

      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// Captures and uploads multiple images
  /// Returns a list of download URLs
  Future<List<String>> captureAndUploadImages({
    required String organizationId,
    required String recordType,
    required String recordId,
    required int maxImages,
    void Function(int current, int total)? onProgress,
  }) async {
    final List<String> imageUrls = [];

    for (int i = 0; i < maxImages; i++) {
      // Capture image
      final imageFile = await captureImage();
      if (imageFile == null) {
        break; // User cancelled or error occurred
      }

      // Upload image
      final url = await uploadImage(
        imageFile: imageFile,
        organizationId: organizationId,
        recordType: recordType,
        recordId: recordId,
        onProgress: (progress) {
          onProgress?.call(i, maxImages);
        },
      );

      if (url != null) {
        imageUrls.add(url);
      }

      // Clean up temporary file
      try {
        await imageFile.delete();
      } catch (e) {
        _logger.warning('Failed to delete temporary image file', e);
      }
    }

    return imageUrls;
  }

  /// Deletes an image from Firebase Storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Get reference from URL
      final ref = _storage.refFromURL(imageUrl);

      // Delete the file
      await ref.delete();

      _logger.info('Image deleted successfully: $imageUrl');
      return true;
    } catch (e) {
      _logger.error('Error deleting image', e);
      return false;
    }
  }

  /// Deletes multiple images from Firebase Storage
  Future<void> deleteImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImage(url);
    }
  }

  /// Queues an image upload for offline processing.
  ///
  /// When the device is offline, this method stores the image bytes in the
  /// offline queue for later upload when connectivity is restored. The image
  /// is base64 encoded and stored in the operation metadata.
  ///
  /// Returns a [QueuedPhotoUpload] with the storage path that will be used
  /// when the upload is processed, or null if queueing fails.
  ///
  /// Pattern follows KML offline upload from outplant_geometry_components.dart.
  Future<QueuedPhotoUpload?> queueOfflineUpload({
    required Uint8List imageBytes,
    required String fileName,
    required String recordType,
    required String recordId,
    required String eventId,
    required String organizationId,
    ConnectivityService? connectivity,
    OfflineQueue? offlineQueue,
  }) async {
    final conn = connectivity ?? ConnectivityService.instance;
    final queue = offlineQueue ?? OfflineQueue.instance;

    // If online, caller should use direct upload instead
    if (conn.isOnline) {
      _logger.warning(
        'queueOfflineUpload called while online - use uploadImageBytes instead',
      );
      return null;
    }

    try {
      final resolvedOrgId = _requireOrganizationStorageKey(
        organizationId,
        operation: 'queueOfflineUpload',
      );
      // Generate storage path matching online upload pattern
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(fileName);
      final storedFileName = '${timestamp}_$recordId.$extension';
      final storagePath = _buildStoragePath(
        organizationId: resolvedOrgId,
        recordType: recordType,
        recordId: recordId,
        fileName: storedFileName,
      );

      final uploadedAt = DateTime.now().toUtc();

      // Queue the upload operation
      final operation = PendingOperation(
        id: 'photo_upload_${eventId}_${uploadedAt.millisecondsSinceEpoch}',
        type: OperationType.createEvent, // Use createEvent as closest match
        modelType: ModelType.event,
        data: {
          'eventId': eventId,
          'organizationId': organizationId,
        },
        createdAt: DateTime.now(),
        metadata: {
          'operation': 'photo_upload',
          'eventId': eventId,
          'organizationId': resolvedOrgId,
          'organizationDomain': resolvedOrgId,
          'recordType': recordType,
          'recordId': recordId,
          'storagePath': storagePath,
          'fileName': fileName,
          'fileSizeBytes': imageBytes.length,
          'contentType': _getContentType(fileName),
          'photoBytes': base64Encode(imageBytes),
        },
      );

      await queue.addOperation(operation);

      _logger.info(
        'Queued photo upload for offline processing: $storagePath',
      );

      return QueuedPhotoUpload(
        storagePath: storagePath,
        fileName: fileName,
        fileSizeBytes: imageBytes.length,
        queuedAt: uploadedAt,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to queue photo upload for event $eventId',
        error,
        stackTrace,
      );
      return null;
    }
  }
}

/// Cross-platform container for picked image data (bytes + filename).
class PickedImageData {
  const PickedImageData({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// Represents a photo upload that has been queued for offline processing.
///
/// Contains the storage path that will be used when the upload is processed,
/// allowing callers to reference the future location of the image.
class QueuedPhotoUpload {
  const QueuedPhotoUpload({
    required this.storagePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.queuedAt,
  });

  /// The Firebase Storage path where the image will be uploaded.
  final String storagePath;

  /// The original filename of the image.
  final String fileName;

  /// The size of the image in bytes.
  final int fileSizeBytes;

  /// When the upload was queued.
  final DateTime queuedAt;
}

class ImageUploadException implements Exception {
  const ImageUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
