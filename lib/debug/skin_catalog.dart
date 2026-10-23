import 'package:flutter/services.dart';

class SkinFolderInfo {
  const SkinFolderInfo({required this.name, required this.spriteCount});

  final String name;
  final int spriteCount;

  /// First 14 characters, two lines of up to 7.
  String get twoLineLabel {
    final clipped = name.length <= 14 ? name : name.substring(0, 14);
    if (clipped.length <= 7) return clipped;
    return '${clipped.substring(0, 7)}\n${clipped.substring(7)}';
  }
}

/// Discovers `assets/images/skins/<folder>/` from the Flutter asset manifest.
class SkinCatalog {
  SkinCatalog._();

  static const prefix = 'assets/images/skins/';

  static const _imageExt = {'.webp', '.png', '.jpg', '.jpeg', '.gif'};

  static Future<List<SkinFolderInfo>> load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final counts = <String, int>{};
    for (final asset in manifest.listAssets()) {
      if (!asset.startsWith(prefix)) continue;
      final rest = asset.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash <= 0) continue;
      final folder = rest.substring(0, slash);
      final file = rest.substring(slash + 1);
      if (file.contains('/')) continue;
      if (!_isImage(file)) continue;
      counts[folder] = (counts[folder] ?? 0) + 1;
    }
    final names = counts.keys.toList()..sort();
    return [
      for (final name in names)
        SkinFolderInfo(name: name, spriteCount: counts[name]!),
    ];
  }

  static bool _isImage(String file) {
    final dot = file.lastIndexOf('.');
    if (dot < 0) return false;
    return _imageExt.contains(file.substring(dot).toLowerCase());
  }
}
