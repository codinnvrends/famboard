import 'package:flutter/material.dart';

import 'models.dart';

/// A node in the category tree. Ids are dotted paths: `groceries.dairy`.
class CategoryDef {
  const CategoryDef(this.id, this.en, this.hi, this.icon, this.color);

  final String id;
  final String en;
  final String hi;
  final IconData icon;
  final Color color;

  String get parentId => id.contains('.') ? id.split('.').first : id;
  bool get isTop => !id.contains('.');

  String name(Locale locale) => locale.languageCode == 'hi' ? hi : en;
}

const _grocery = Color(0xFF2E7D32);
const _household = Color(0xFF00838F);
const _repair = Color(0xFFD84315);
const _upgrade = Color(0xFF5E35B1);
const _bill = Color(0xFF1565C0);
const _health = Color(0xFFC2185B);
const _kids = Color(0xFFF9A825);
const _chores = Color(0xFF6D4C41);
const _other = Color(0xFF546E7A);

/// Default category tree (spec section 6). Order here is the store-section
/// order used in Shopping mode.
const List<CategoryDef> builtInCategories = [
  CategoryDef('groceries', 'Groceries', 'किराना', Icons.local_grocery_store, _grocery),
  CategoryDef('groceries.produce', 'Vegetables & fruit', 'सब्ज़ी-फल', Icons.eco, _grocery),
  CategoryDef('groceries.dairy', 'Dairy', 'डेयरी', Icons.water_drop, _grocery),
  CategoryDef('groceries.staples', 'Staples', 'राशन', Icons.rice_bowl, _grocery),
  CategoryDef('groceries.spices', 'Spices', 'मसाले', Icons.local_fire_department, _grocery),
  CategoryDef('groceries.snacks', 'Snacks', 'नाश्ता', Icons.cookie, _grocery),
  CategoryDef('groceries.beverages', 'Beverages', 'पेय', Icons.local_cafe, _grocery),
  CategoryDef('household', 'Household supplies', 'घरेलू सामान', Icons.home, _household),
  CategoryDef('household.cleaning', 'Cleaning', 'सफ़ाई', Icons.cleaning_services, _household),
  CategoryDef('household.toiletries', 'Toiletries', 'प्रसाधन', Icons.soap, _household),
  CategoryDef('household.kitchen', 'Kitchen consumables', 'रसोई सामान', Icons.kitchen, _household),
  CategoryDef('repairs', 'Repairs & maintenance', 'मरम्मत', Icons.build, _repair),
  CategoryDef('repairs.plumbing', 'Plumbing', 'प्लंबिंग', Icons.plumbing, _repair),
  CategoryDef('repairs.electrical', 'Electrical', 'बिजली का काम', Icons.electrical_services, _repair),
  CategoryDef('repairs.appliances', 'Appliances', 'उपकरण', Icons.kitchen_outlined, _repair),
  CategoryDef('repairs.carpentry', 'Carpentry', 'बढ़ईगिरी', Icons.carpenter, _repair),
  CategoryDef('repairs.vehicle', 'Vehicle', 'वाहन', Icons.two_wheeler, _repair),
  CategoryDef('upgrades', 'Upgrades & purchases', 'नई ख़रीद', Icons.upgrade, _upgrade),
  CategoryDef('upgrades.electronics', 'Electronics', 'इलेक्ट्रॉनिक्स', Icons.devices, _upgrade),
  CategoryDef('upgrades.furniture', 'Furniture', 'फ़र्नीचर', Icons.chair, _upgrade),
  CategoryDef('upgrades.appliances', 'Appliances', 'उपकरण', Icons.blender, _upgrade),
  CategoryDef('upgrades.clothing', 'Clothing', 'कपड़े', Icons.checkroom, _upgrade),
  CategoryDef('bills', 'Bills & payments', 'बिल और भुगतान', Icons.receipt_long, _bill),
  CategoryDef('bills.electricity', 'Electricity', 'बिजली बिल', Icons.bolt, _bill),
  CategoryDef('bills.water', 'Water', 'पानी', Icons.water, _bill),
  CategoryDef('bills.gas', 'Gas', 'गैस', Icons.propane_tank, _bill),
  CategoryDef('bills.internet', 'Internet & mobile', 'इंटरनेट-मोबाइल', Icons.wifi, _bill),
  CategoryDef('bills.rent', 'Rent / EMI', 'किराया / EMI', Icons.house, _bill),
  CategoryDef('bills.insurance', 'Insurance', 'बीमा', Icons.shield, _bill),
  CategoryDef('bills.fees', 'School fees', 'स्कूल फ़ीस', Icons.school, _bill),
  CategoryDef('bills.subscriptions', 'Subscriptions', 'सब्सक्रिप्शन', Icons.subscriptions, _bill),
  CategoryDef('bills.card', 'Credit card', 'क्रेडिट कार्ड', Icons.credit_card, _bill),
  CategoryDef('health', 'Health', 'स्वास्थ्य', Icons.favorite, _health),
  CategoryDef('health.medicines', 'Medicines', 'दवाइयाँ', Icons.medication, _health),
  CategoryDef('health.appointments', 'Appointments', 'अपॉइंटमेंट', Icons.event, _health),
  CategoryDef('kids', 'Kids & school', 'बच्चे और स्कूल', Icons.child_care, _kids),
  CategoryDef('kids.stationery', 'Stationery', 'स्टेशनरी', Icons.edit, _kids),
  CategoryDef('kids.uniform', 'Uniform', 'यूनिफ़ॉर्म', Icons.dry_cleaning, _kids),
  CategoryDef('kids.activities', 'Activities', 'गतिविधियाँ', Icons.sports_soccer, _kids),
  CategoryDef('chores', 'Chores & tasks', 'घर के काम', Icons.task_alt, _chores),
  CategoryDef('chores.errands', 'Errands', 'बाहर के काम', Icons.directions_walk, _chores),
  CategoryDef('chores.paperwork', 'Paperwork', 'काग़ज़ात', Icons.description, _chores),
  CategoryDef('chores.cleaning', 'Cleaning jobs', 'सफ़ाई के काम', Icons.cleaning_services, _chores),
  CategoryDef('other', 'Other', 'अन्य', Icons.category, _other),
];

final Map<String, CategoryDef> _byId = {
  for (final c in builtInCategories) c.id: c,
};

/// Category to fall back on when only the entry type is known.
const Map<EntryType, String> defaultCategoryForType = {
  EntryType.needToBuy: 'groceries',
  EntryType.outOfStock: 'groceries',
  EntryType.repair: 'repairs',
  EntryType.upgrade: 'upgrades',
  EntryType.bill: 'bills',
  EntryType.task: 'chores',
};

/// Looks up a category, including family custom ones.
CategoryDef categoryById(
  String id, {
  List<CustomCategory> custom = const [],
}) {
  final builtIn = _byId[id];
  if (builtIn != null) return builtIn;
  for (final c in custom) {
    if (c.id == id) {
      final parent = _byId[c.parentId] ?? _byId['other']!;
      return CategoryDef(c.id, c.name, c.name, parent.icon, parent.color);
    }
  }
  final parent = _byId[id.split('.').first];
  return parent ?? _byId['other']!;
}

/// Position in the store-section order (shopping mode sorting).
int categoryOrder(String id) {
  final i = builtInCategories.indexWhere((c) => c.id == id);
  if (i >= 0) return i;
  final p = builtInCategories.indexWhere((c) => c.id == id.split('.').first);
  return p >= 0 ? p : builtInCategories.length;
}
