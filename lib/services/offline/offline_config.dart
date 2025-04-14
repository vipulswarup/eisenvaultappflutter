/// Configuration settings for offline functionality
class OfflineConfig {
  /// Minimum required space in bytes for offline storage
  final int minRequiredSpace;

  /// Maximum storage space in bytes
  final int maxStorageSpace;

  /// Whether to automatically sync when online
  final bool autoSync;

  /// How often to check for updates (in minutes)
  final int syncInterval;

  const OfflineConfig({
    this.minRequiredSpace = 10 * 1024 * 1024, // 10MB
    this.maxStorageSpace = 1024 * 1024 * 1024, // 1GB
    this.autoSync = true,
    this.syncInterval = 15,
  });
} 