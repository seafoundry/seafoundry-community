// @tier: community
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/services/image_service.dart';

/// Shared helper for image picking and upload flows across dialogs.
class ImageWorkflowService {
  static ImageService resolveImageService(BuildContext context) {
    try {
      final provided = context.read<ImageService?>();
      if (provided != null) return provided;
    } on ProviderNotFoundException {
      // Fall through to FirebaseService-based instantiation.
    }

    try {
      final firebaseService = context.read<FirebaseService>();
      return ImageService(firebaseService: firebaseService);
    } on ProviderNotFoundException catch (e) {
      throw Exception(
        'Image services not available. Please ensure ImageService or FirebaseService '
        'is provided. Error: $e',
      );
    }
  }

  /// Picks an image file (native only). Returns null on web.
  /// Prefer [pickImageBytesFromContext] for cross-platform support.
  static Future<File?> pickImageFile(
    BuildContext context, {
    List<String>? allowedExtensions,
  }) async {
    final imageService = resolveImageService(context);
    return imageService.pickImageFile(allowedExtensions: allowedExtensions);
  }

  /// Picks an image as bytes. Works on all platforms (web + native).
  static Future<PickedImageData?> pickImageBytesFromContext(
    BuildContext context, {
    List<String>? allowedExtensions,
  }) async {
    final imageService = resolveImageService(context);
    return imageService.pickImageBytes(allowedExtensions: allowedExtensions);
  }

  static Future<List<File>> pickImageFiles(
    BuildContext context, {
    List<String>? allowedExtensions,
  }) async {
    final imageService = resolveImageService(context);
    return imageService.pickImageFiles(allowedExtensions: allowedExtensions);
  }

  static Future<String?> uploadImage({
    required BuildContext context,
    required File imageFile,
    required String organizationId,
    required String recordType,
    required String recordId,
    void Function(double)? onProgress,
    Duration? timeout,
  }) async {
    final imageService = resolveImageService(context);
    return uploadImageWithService(
      imageService: imageService,
      imageFile: imageFile,
      organizationId: organizationId,
      recordType: recordType,
      recordId: recordId,
      onProgress: onProgress,
      timeout: timeout,
    );
  }

  static Future<String?> uploadImageWithService({
    required ImageService imageService,
    required File imageFile,
    required String organizationId,
    required String recordType,
    required String recordId,
    void Function(double)? onProgress,
    Duration? timeout,
  }) async {
    final uploadFuture = imageService.uploadImage(
      imageFile: imageFile,
      organizationId: organizationId,
      recordType: recordType,
      recordId: recordId,
      onProgress: onProgress,
    );
    if (timeout == null) {
      return uploadFuture;
    }
    return uploadFuture.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'uploadImage timed out after ${timeout.inSeconds} seconds',
      ),
    );
  }

  /// Uploads image bytes to Firebase Storage (works on all platforms).
  static Future<String?> uploadImageBytesWithService({
    required ImageService imageService,
    required Uint8List bytes,
    required String fileName,
    required String organizationId,
    required String recordType,
    required String recordId,
    void Function(double)? onProgress,
    Duration? timeout,
  }) async {
    final uploadFuture = imageService.uploadImageBytes(
      bytes: bytes,
      fileName: fileName,
      organizationId: organizationId,
      recordType: recordType,
      recordId: recordId,
      onProgress: onProgress,
    );
    if (timeout == null) {
      return uploadFuture;
    }
    return uploadFuture.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'uploadImageBytes timed out after ${timeout.inSeconds} seconds',
      ),
    );
  }

  static Future<File?> captureImage(BuildContext context) async {
    final imageService = resolveImageService(context);
    return captureImageWithService(imageService);
  }

  static Future<File?> captureImageWithService(
    ImageService imageService,
  ) async {
    return imageService.captureImage();
  }
}
