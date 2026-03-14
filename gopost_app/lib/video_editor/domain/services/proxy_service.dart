/// DIP: Abstraction for proxy generation so callers don't depend on the
/// concrete FFmpeg-backed implementation.
abstract class ProxyService {
  Future<String?> existingProxyPath(String sourcePath);

  Future<String?> generateProxy(
    String sourcePath, {
    void Function(double progress)? onProgress,
  });

  Future<void> cancelAll();

  Future<void> clearProxyForSource(String sourcePath);

  Future<int> clearAllProxies();

  Future<int> getCacheSize();

  Future<bool> verifyProxy(String proxyPath);
}
