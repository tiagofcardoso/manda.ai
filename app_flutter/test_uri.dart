void main() {
  try {
    final query = 'Rua Bom jesus, Pinhais, Brasil';
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
    print(url.toString());
  } catch (e) {
    print('Error: $e');
  }
}
