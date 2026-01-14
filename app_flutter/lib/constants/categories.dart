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
  // New Categories
  'italian': {
    'id': '2921be16-ca80-4a37-835b-ed77dbcc3e6b',
    'label': 'Italiana',
    'en_label': 'Italian',
    'icon': LucideIcons.chefHat,
    'color': Colors.redAccent,
  },
  'japanese': {
    'id': '6446f21d-79b0-4b50-89a9-113ffc6a3e46',
    'label': 'Japonesa',
    'en_label': 'Japanese',
    'icon': LucideIcons.soup,
    'color': Colors.red,
  },
  'chinese': {
    'id': '4593d393-453d-4658-af9e-5ca4904e8ad7',
    'label': 'Chinesa',
    'en_label': 'Chinese',
    'icon': LucideIcons.utensilsCrossed,
    'color': Colors.red[900],
  },
  'brazilian': {
    'id': '5b54f7d7-9d4d-4c15-963c-1d29fdcee239',
    'label': 'Brasileira',
    'en_label': 'Brazilian',
    'icon': LucideIcons.flame,
    'color': Colors.green[700],
  },
  'portuguese': {
    'id': 'aac0718c-6ac2-4786-ac2d-77f6c5f83604',
    'label': 'Portuguesa',
    'en_label': 'Portuguese',
    'icon': LucideIcons.wine,
    'color': Colors.deepPurple,
  },
  'mexican': {
    'id': 'e2c84d88-ee21-4a4d-a941-df8c0a0157b4',
    'label': 'Mexicana',
    'en_label': 'Mexican',
    'icon': LucideIcons.sun,
    'color': Colors.orange[800],
  },
  'healthy': {
    'id': '34491092-3ef3-4370-a965-e279639ae0f2',
    'label': 'Saudável',
    'en_label': 'Healthy',
    'icon': LucideIcons.apple,
    'color': Colors.lightGreen,
  },
  'pastry': {
    'id': 'ee4f4efc-2ca6-4221-8718-d1d0e91b427f',
    'label': 'Pastelaria',
    'en_label': 'Pastry',
    'icon': LucideIcons.croissant,
    'color': Colors.amber[200],
  },
  'seafood': {
    'id': 'bba723ef-715b-4039-9397-8b5a24a3d567',
    'label': 'Peixes',
    'en_label': 'Seafood',
    'icon': LucideIcons.fish,
    'color': Colors.lightBlue,
  },
  'vegetarian': {
    'id': 'a1bf7f4b-1e86-487c-ab6f-7250432f6983',
    'label': 'Vegetariana',
    'en_label': 'Vegetarian',
    'icon': LucideIcons.carrot,
    'color': Colors.green,
  },
};
