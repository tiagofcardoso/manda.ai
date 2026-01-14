import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ImageHelper {
  static ImageProvider getProductImage(String? productName, String? imageUrl) {
    if (productName == null) {
      return const NetworkImage(
          'https://via.placeholder.com/150'); // Safe fallback
    }

    final name = productName.toLowerCase();

    // Override with local assets for demo
    if (name.contains('classic smash')) {
      return const AssetImage('assets/images/classic_smash.png');
    }
    if (name.contains('truffle') || name.contains('mushroom')) {
      return const AssetImage('assets/images/truffle_mushroom.png');
    }
    if (name.contains('craft') ||
        name.contains('ipa') ||
        name.contains('beer')) {
      return const AssetImage('assets/images/craft_ipa.png');
    }

    // Fallback to network if URL exists
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }

    // Final fallback
    return const NetworkImage('https://via.placeholder.com/300?text=Manda.AI');
  }

  // Helper widget builder for consistent parsing
  static Widget buildProductImage(String? name, String? url,
      {double width = 50, double height = 50}) {
    return Image(
      image: getProductImage(name, url),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[800],
          child:
              const Icon(LucideIcons.utensils, color: Colors.white24, size: 20),
        );
      },
    );
  }
}
