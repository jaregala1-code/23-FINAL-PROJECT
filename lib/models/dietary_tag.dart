class DietaryTag {
  final String id;
  final String label;
  final String emoji;

  const DietaryTag({
    required this.id,
    required this.label,
    required this.emoji,
  });
}

class AppTags {
  static const List<DietaryTag> dietary = [
    DietaryTag(id: 'vegan', label: 'Vegan', emoji: '🌱'),
    DietaryTag(id: 'vegetarian', label: 'Vegetarian', emoji: '🥦'),
    DietaryTag(id: 'halal', label: 'Halal', emoji: '☪️'),
    DietaryTag(id: 'gluten_free', label: 'Gluten-Free', emoji: '🌾'),
    DietaryTag(id: 'dairy_free', label: 'Dairy-Free', emoji: '🥛'),
    DietaryTag(id: 'nut_free', label: 'Nut-Free', emoji: '🥜'),
    DietaryTag(id: 'raw', label: 'Raw Ingredients', emoji: '🥕'),
    DietaryTag(id: 'home_cooked', label: 'Home-Cooked', emoji: '🍳'),
    DietaryTag(id: 'organic', label: 'Organic', emoji: '♻️'),
    DietaryTag(id: 'pescatarian', label: 'Pescatarian', emoji: '🐟'),
    DietaryTag(id: 'keto', label: 'Keto', emoji: '🥑'),
    DietaryTag(id: 'paleo', label: 'Paleo', emoji: '🍖'),
    DietaryTag(id: 'kosher', label: 'Kosher', emoji: '✡️'),
    DietaryTag(id: 'low_sugar', label: 'Low-Sugar', emoji: '🍬'),
    DietaryTag(id: 'spicy', label: 'Spicy Food', emoji: '🌶️'),
    DietaryTag(id: 'bakery', label: 'Bakery & Bread', emoji: '🥖'),
    DietaryTag(id: 'fruit', label: 'Fresh Fruits', emoji: '🍎'),
    DietaryTag(id: 'pantry', label: 'Pantry Staples', emoji: '🫙'),
  ];
}
