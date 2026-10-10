/// Race de lapin renvoyée par le serveur, avec sa photo quand elle est disponible.
class Breed {
  final String id;
  final String name;
  final String? imageUrl;

  const Breed({required this.id, required this.name, this.imageUrl});

  factory Breed.fromJson(Map<String, dynamic> json) {
    return Breed(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      imageUrl: json['image'],
    );
  }
}
