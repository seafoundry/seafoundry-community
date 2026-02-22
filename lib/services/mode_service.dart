// @tier: community
import 'package:flutter/foundation.dart';

/// UI modes for the application
enum UIMode {
  mobile,
  desktop,
  auto, // Automatically determines based on platform
}

/// Service for managing UI mode preferences
class ModeService {
  static final ModeService _instance = ModeService._internal();
  static ModeService get instance => _instance;

  ModeService._internal();

  UIMode _currentMode = UIMode.auto;
  bool _mobileFeaturesEnabled = true;

  /// Get the current UI mode
  UIMode get currentMode => _currentMode;

  /// Set the UI mode
  void setMode(UIMode mode) {
    _currentMode = mode;
  }

  /// Gate mobile surfaces (Community tier disables mobile shell entirely).
  void setMobileFeatureGate(bool enabled) {
    _mobileFeaturesEnabled = enabled;
    if (!enabled && _currentMode == UIMode.mobile) {
      _currentMode = UIMode.desktop;
    }
  }

  /// Check if desktop features should be shown
  bool get shouldShowDesktopFeatures {
    if (!_mobileFeaturesEnabled) {
      return true;
    }
    switch (_currentMode) {
      case UIMode.desktop:
        return true;
      case UIMode.mobile:
        return false;
      case UIMode.auto:
        // For web and auto mode, default to desktop features
        return kIsWeb;
    }
  }

  /// Check if mobile features should be shown
  bool get shouldShowMobileFeatures {
    if (!_mobileFeaturesEnabled) {
      return false;
    }
    switch (_currentMode) {
      case UIMode.mobile:
        return true;
      case UIMode.desktop:
        return false;
      case UIMode.auto:
        return !kIsWeb;
    }
  }
}
