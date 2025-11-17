class InventoryItem {
  final String name;
  final String category;
  final String fillingMethod;
  final int quantityPerUnit;

  InventoryItem({
    required this.name,
    required this.category,
    required this.fillingMethod,
    required this.quantityPerUnit,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'fillingMethod': fillingMethod,
      'quantityPerUnit': quantityPerUnit,
    };
  }
}
