import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Key -> {label, icon}
// Using generic icons for now. In a real app with uniform 3D assets,
// we would replace 'icon' with 'assetPath'.
final Map<String, Map<String, dynamic>> APP_CATEGORIES = {
  'all': {
    'id': 'all',
    'label': 'Todos',
    'en_label': 'All',
    'icon': LucideIcons.layoutGrid,
    'color': Colors.grey,
  },
  'burgers': {
    'id': '327606c4-16e4-42b6-8f8d-b9148d6f3838',
    'label': 'Burgers',
    'en_label': 'Burgers',
    'icon': LucideIcons.sandwich, // Closest icon
    'color': Colors.orangeAccent,
  },
  'fast_food': {
    'id': '7df9a4ad-3f87-480f-975b-28230153c2f4',
    'label': 'Fast food',
    'en_label': 'Fast Food',
    'icon': LucideIcons.utensils,
    'color': Color(0xFFE63946),
  },
  'pizza': {
    'id': 'fa7cbd82-c463-47e3-b813-444793a3144a',
    'label': 'Pizzas',
    'en_label': 'Pizzas',
    'icon': LucideIcons.pizza,
    'color': Colors.orange,
  },
  'sushi': {
    'id': 'cb839d56-fb6a-40bd-9830-bbff9f5275ba',
    'label': 'Sushi',
    'en_label': 'Sushi',
    'icon': LucideIcons.fish,
    'color': Colors.redAccent,
  },
  'bbq': {
    'id': 'd48c9e17-fa5c-4571-8564-f0a593f12944',
    'label': 'Churrasco',
    'en_label': 'BBQ',
    'icon': LucideIcons.flame,
    'color': Colors.brown,
  },
  'sandwiches': {
    'id': 'e4834752-7fa4-4e4f-9153-59f72077728c',
    'label': 'Sanduíches',
    'en_label': 'Sandwiches',
    'icon': LucideIcons.sandwich,
    'color': Colors.amber,
  },
  'vegan': {
    'id': '83667288-e8fc-46dd-8565-37b4eaf92fba',
    'label': 'Vegano',
    'en_label': 'Vegan',
    'icon': LucideIcons.leaf,
    'color': Colors.green,
  },
  'drinks': {
    'id': '0fa83a66-5b37-4d62-9426-a9c1d40ee859',
    'label': 'Bebidas',
    'en_label': 'Drinks',
    'icon': LucideIcons.beer,
    'color': Colors.blue,
  },
  'dessert': {
    'id': '1113c888-9859-4291-ba6e-359319a7cfa2',
    'label': 'Sobremesas',
    'en_label': 'Desserts',
    'icon': LucideIcons.iceCream2,
    'color': Colors.purple,
  },
};
