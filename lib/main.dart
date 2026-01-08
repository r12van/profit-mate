import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Kita inisialisasi Provider dengan data yang dimuat dari memori
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider(prefs)),
      ],
      child: const ProfitMateApp(),
    ),
  );
}

// ================== 1. MODEL DATA (ANTI-CRASH VERSION) ==================

// Helper agar tidak error saat convert angka
double safeDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class MaterialItem {
  String id;
  String name;
  String supplier;
  double totalCost;
  double quantity;
  String unit;

  MaterialItem({
    required this.id,
    required this.name,
    required this.supplier,
    required this.totalCost,
    required this.quantity,
    required this.unit,
  });

  double get pricePerUnit => (quantity > 0) ? totalCost / quantity : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'supplier': supplier,
    'totalCost': totalCost,
    'quantity': quantity,
    'unit': unit,
  };

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id']?.toString() ?? DateTime.now().toString(),
      name: json['name']?.toString() ?? 'Tanpa Nama',
      supplier: json['supplier']?.toString() ?? '-',
      totalCost: safeDouble(json['totalCost']), // Pakai safeDouble
      quantity: safeDouble(json['quantity']),     // Pakai safeDouble
      unit: json['unit']?.toString() ?? 'pcs',
    );
  }
}

class UsedMaterial {
  MaterialItem material;
  double usedQty;

  UsedMaterial({required this.material, required this.usedQty});
  double get cost => material.pricePerUnit * usedQty;

  Map<String, dynamic> toJson() => {
    'material': material.toJson(),
    'usedQty': usedQty,
  };

  factory UsedMaterial.fromJson(Map<String, dynamic> json) {
    // Cek jika material null (data korup), buat dummy biar gak crash
    var matData = json['material'] != null ? MaterialItem.fromJson(json['material']) 
                  : MaterialItem(id: '0', name: 'Unknown', supplier: '-', totalCost: 0, quantity: 1, unit: 'pcs');
    
    return UsedMaterial(
      material: matData,
      usedQty: safeDouble(json['usedQty']),
    );
  }
}

class SavedRecipe {
  String id;
  String name;
  List<UsedMaterial> materials;
  double laborCost;
  double packagingCost;
  double shippingCost;
  double markupPercent;

  SavedRecipe({
    required this.id,
    required this.name,
    required this.materials,
    required this.laborCost,
    required this.packagingCost,
    required this.shippingCost,
    required this.markupPercent,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'materials': materials.map((e) => e.toJson()).toList(),
    'laborCost': laborCost,
    'packagingCost': packagingCost,
    'shippingCost': shippingCost,
    'markupPercent': markupPercent,
  };

  factory SavedRecipe.fromJson(Map<String, dynamic> json) {
    var matList = json['materials'] as List? ?? []; // Handle null list
    return SavedRecipe(
      id: json['id']?.toString() ?? DateTime.now().toString(),
      name: json['name']?.toString() ?? 'Resep Tanpa Nama',
      materials: matList.map((e) => UsedMaterial.fromJson(e)).toList(),
      laborCost: safeDouble(json['laborCost']),
      packagingCost: safeDouble(json['packagingCost']),
      shippingCost: safeDouble(json['shippingCost']),
      markupPercent: safeDouble(json['markupPercent']),
    );
  }
}
// ================== 2. LOGIC PROVIDER (DATABASE) ==================

class AppProvider with ChangeNotifier {
  final SharedPreferences prefs;
  
  List<MaterialItem> _materials = [];
  List<SavedRecipe> _savedRecipes = [];

  // Variabel Kalkulator Aktif
  List<UsedMaterial> _currentRecipe = [];
  String _currentRecipeName = "Resep Baru";
  double _laborCost = 0;
  double _packagingCost = 0;
  double _shippingCost = 0;
  double _markupPercent = 30;

  AppProvider(this.prefs) {
    _loadFromPrefs();
  }

  // Getters
  List<MaterialItem> get materials => _materials;
  List<SavedRecipe> get savedRecipes => _savedRecipes;
  List<UsedMaterial> get currentRecipe => _currentRecipe;
  String get currentRecipeName => _currentRecipeName;
  double get laborCost => _laborCost;
  double get packagingCost => _packagingCost;
  double get shippingCost => _shippingCost;
  double get markupPercent => _markupPercent;

  // --- DATABASE LOGIC ---

  void _loadFromPrefs() {
    // Load Materials
    String? matString = prefs.getString('materials');
    if (matString != null) {
      List<dynamic> jsonList = jsonDecode(matString);
      _materials = jsonList.map((e) => MaterialItem.fromJson(e)).toList();
    } else {
      // Data Dummy Awal jika kosong
      _materials = [
        MaterialItem(id: '1', name: 'Kopi Beans', supplier: 'Petani', totalCost: 150000, quantity: 1000, unit: 'gram'),
        MaterialItem(id: '2', name: 'Susu', supplier: 'Toko', totalCost: 24000, quantity: 1000, unit: 'ml'),
      ];
    }

    // Load Recipes
    String? recString = prefs.getString('recipes');
    if (recString != null) {
      List<dynamic> jsonList = jsonDecode(recString);
      _savedRecipes = jsonList.map((e) => SavedRecipe.fromJson(e)).toList();
    }
    notifyListeners();
  }

  void _saveMaterialsToPrefs() {
    String jsonString = jsonEncode(_materials.map((e) => e.toJson()).toList());
    prefs.setString('materials', jsonString);
  }

  void _saveRecipesToPrefs() {
    String jsonString = jsonEncode(_savedRecipes.map((e) => e.toJson()).toList());
    prefs.setString('recipes', jsonString);
  }

  // --- ACTIONS ---

  void addMaterial(MaterialItem item) {
    _materials.add(item);
    _saveMaterialsToPrefs();
    notifyListeners();
  }

  void deleteMaterial(int index) {
    _materials.removeAt(index);
    _saveMaterialsToPrefs();
    notifyListeners();
  }

  // --- Calculator Logic ---

  void addToRecipe(MaterialItem item, double qty) {
    _currentRecipe.add(UsedMaterial(material: item, usedQty: qty));
    notifyListeners();
  }

  void removeRecipeItem(int index) {
    _currentRecipe.removeAt(index);
    notifyListeners();
  }

  void updateCosts({double? labor, double? pack, double? ship, double? markup, String? name}) {
    if (labor != null) _laborCost = labor;
    if (pack != null) _packagingCost = pack;
    if (ship != null) _shippingCost = ship;
    if (markup != null) _markupPercent = markup;
    if (name != null) _currentRecipeName = name;
    notifyListeners();
  }

  void resetCalculator() {
    _currentRecipe.clear();
    _currentRecipeName = "Resep Baru";
    _laborCost = 0;
    _packagingCost = 0;
    _shippingCost = 0;
    notifyListeners();
  }

  void loadRecipeToCalculator(SavedRecipe recipe) {
    _currentRecipe = List.from(recipe.materials); // Copy list
    _currentRecipeName = recipe.name;
    _laborCost = recipe.laborCost;
    _packagingCost = recipe.packagingCost;
    _shippingCost = recipe.shippingCost;
    _markupPercent = recipe.markupPercent;
    notifyListeners();
  }

  void saveCurrentRecipe() {
    if (_currentRecipe.isEmpty) return;

    final newRecipe = SavedRecipe(
      id: DateTime.now().toString(),
      name: _currentRecipeName,
      materials: List.from(_currentRecipe),
      laborCost: _laborCost,
      packagingCost: _packagingCost,
      shippingCost: _shippingCost,
      markupPercent: _markupPercent,
    );

    // Cek apakah update atau baru (logic sederhana: selalu tambah baru utk sekarang)
    _savedRecipes.add(newRecipe);
    _saveRecipesToPrefs();
    notifyListeners();
  }

  void deleteSavedRecipe(int index) {
    _savedRecipes.removeAt(index);
    _saveRecipesToPrefs();
    notifyListeners();
  }

  // --- Perhitungan ---
  double get totalMaterialCost => _currentRecipe.fold(0, (sum, item) => sum + item.cost);
  double get totalBaseCost => totalMaterialCost + _laborCost + _packagingCost + _shippingCost;
  double get preTaxPrice => totalBaseCost * (1 + (_markupPercent / 100));
  double get profitAmount => preTaxPrice - totalBaseCost;
}

// ================== 3. UI ==================

class ProfitMateApp extends StatelessWidget {
  const ProfitMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profit Mate',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true, scaffoldBackgroundColor: Colors.grey[100]),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _pages = [const CalculatorScreen(), const RecipeBookScreen(), const MaterialListScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate), label: 'Kalkulator'),
          NavigationDestination(icon: Icon(Icons.book), label: 'Buku Resep'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Stok Bahan'),
        ],
      ),
    );
  }
}

// --- SCREEN 1: KALKULATOR ---

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Kalkulator'),
            actions: [
              IconButton(icon: const Icon(Icons.cleaning_services), onPressed: () => provider.resetCalculator(), tooltip: "Bersihkan"),
              IconButton(icon: const Icon(Icons.save), onPressed: () => _showSaveDialog(context, provider), tooltip: "Simpan Resep"),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: TextEditingController(text: provider.currentRecipeName),
                  decoration: const InputDecoration(labelText: "Nama Produk / Resep", prefixIcon: Icon(Icons.label)),
                  onChanged: (val) => provider.updateCosts(name: val),
                ),
                const SizedBox(height: 15),
                // Section 1: Bahan
                const Text("1. Komposisi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                Card(
                  child: Column(
                    children: [
                       if (provider.currentRecipe.isEmpty) const Padding(padding: EdgeInsets.all(10), child: Text("Belum ada bahan")),
                       ...provider.currentRecipe.asMap().entries.map((e) => ListTile(
                         title: Text(e.value.material.name),
                         subtitle: Text("${e.value.usedQty} ${e.value.material.unit}"),
                         trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: ()=>provider.removeRecipeItem(e.key)),
                       )).toList(),
                       ElevatedButton.icon(onPressed: ()=> _showAddMaterialDialog(context), icon: const Icon(Icons.add), label: const Text("Tambah Bahan")),
                       const SizedBox(height: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                // Section 2: Biaya
                const Text("2. Biaya & Margin", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        _inputCost("Tenaga Kerja", provider.laborCost, (v)=>provider.updateCosts(labor: v)),
                        _inputCost("Kemasan", provider.packagingCost, (v)=>provider.updateCosts(pack: v)),
                        _inputCost("Lain-lain", provider.shippingCost, (v)=>provider.updateCosts(ship: v)),
                        Row(children: [
                          const Expanded(child: Text("Markup (%)", style: TextStyle(fontWeight: FontWeight.bold))),
                          SizedBox(width: 80, child: TextFormField(initialValue: provider.markupPercent.toString(), keyboardType: TextInputType.number, onChanged: (v)=>provider.updateCosts(markup: double.tryParse(v)??0))),
                        ])
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Result
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      _rowResult("HPP (Modal)", provider.totalBaseCost, currency),
                      _rowResult("Profit", provider.profitAmount, currency),
                      const Divider(color: Colors.white),
                      _rowResult("HARGA JUAL", provider.preTaxPrice, currency, isBig: true),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _inputCost(String label, double val, Function(double) onChg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: TextFormField(
        initialValue: val == 0 ? '' : val.toString(),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, prefixText: "Rp ", isDense: true),
        onChanged: (v) => onChg(double.tryParse(v) ?? 0),
      ),
    );
  }

  Widget _rowResult(String label, double val, NumberFormat fmt, {bool isBig = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.white, fontSize: isBig ? 18 : 14)),
      Text(fmt.format(val), style: TextStyle(color: isBig ? Colors.yellow : Colors.white, fontWeight: FontWeight.bold, fontSize: isBig ? 20 : 14)),
    ]);
  }

  void _showAddMaterialDialog(BuildContext context) {
    showModalBottomSheet(context: context, builder: (ctx) {
      return Consumer<AppProvider>(builder: (context, prov, _) {
        return ListView.builder(
          itemCount: prov.materials.length,
          itemBuilder: (c, i) => ListTile(
            title: Text(prov.materials[i].name),
            trailing: const Icon(Icons.add),
            onTap: () {
              Navigator.pop(ctx);
              _inputQty(context, prov.materials[i]);
            },
          ),
        );
      });
    });
  }

  void _inputQty(BuildContext context, MaterialItem item) {
    final qtyCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Pakai ${item.name}"),
      content: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Jumlah (${item.unit})"), autofocus: true),
      actions: [
        ElevatedButton(onPressed: () {
          double q = double.tryParse(qtyCtrl.text) ?? 0;
          if (q > 0) Provider.of<AppProvider>(context, listen: false).addToRecipe(item, q);
          Navigator.pop(ctx);
        }, child: const Text("OK"))
      ],
    ));
  }

  void _showSaveDialog(BuildContext context, AppProvider prov) {
    if (prov.currentRecipe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bahan masih kosong!")));
      return;
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Simpan Resep Ini?"),
      content: Text("Akan disimpan sebagai '${prov.currentRecipeName}'"),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Batal")),
        ElevatedButton(onPressed: (){
          prov.saveCurrentRecipe();
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Resep Tersimpan!")));
        }, child: const Text("Simpan"))
      ],
    ));
  }
}

// --- SCREEN 2: BUKU RESEP (DATABASE) ---

class RecipeBookScreen extends StatelessWidget {
  const RecipeBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text("Buku Resep Tersimpan")),
      body: provider.savedRecipes.isEmpty 
        ? const Center(child: Text("Belum ada resep disimpan"))
        : ListView.builder(
            itemCount: provider.savedRecipes.length,
            itemBuilder: (ctx, i) {
              final recipe = provider.savedRecipes[i];
              // Hitung total on the fly
              double matCost = recipe.materials.fold(0, (sum, item) => sum + (item.cost));
              double totalHpp = matCost + recipe.laborCost + recipe.packagingCost + recipe.shippingCost;
              double sellPrice = totalHpp * (1 + recipe.markupPercent / 100);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("HPP: ${currency.format(totalHpp)} | Jual: ${currency.format(sellPrice)}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.upload_file, color: Colors.blue),
                        onPressed: () {
                           provider.loadRecipeToCalculator(recipe);
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Resep '${recipe.name}' dimuat ke kalkulator!")));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => provider.deleteSavedRecipe(i),
                      )
                    ],
                  ),
                ),
              );
            },
        ),
    );
  }
}

// --- SCREEN 3: DATA BAHAN ---

class MaterialListScreen extends StatelessWidget {
  const MaterialListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Stok Bahan Baku')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _addMaterial(context),
      ),
      body: ListView.builder(
        itemCount: provider.materials.length,
        itemBuilder: (ctx, i) {
          final item = provider.materials[i];
          return ListTile(
            leading: CircleAvatar(child: Text(item.name[0])),
            title: Text(item.name),
            subtitle: Text("Rp ${item.totalCost} / ${item.quantity} ${item.unit}"),
            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: ()=> provider.deleteMaterial(i)),
          );
        },
      ),
    );
  }

  void _addMaterial(BuildContext context) {
    final n = TextEditingController(), c = TextEditingController(), q = TextEditingController(), u = TextEditingController(text: 'gram');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Tambah Bahan"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: "Nama")),
        TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Harga Beli Total")),
        Row(children: [
          Expanded(child: TextField(controller: q, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Qty"))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: u, decoration: const InputDecoration(labelText: "Satuan"))),
        ]),
      ]),
      actions: [
        ElevatedButton(onPressed: (){
          if(n.text.isNotEmpty) {
            Provider.of<AppProvider>(context, listen: false).addMaterial(MaterialItem(
              id: DateTime.now().toString(), name: n.text, supplier: '', 
              totalCost: double.tryParse(c.text)??0, quantity: double.tryParse(q.text)??1, unit: u.text
            ));
            Navigator.pop(ctx);
          }
        }, child: const Text("Simpan"))
      ],
    ));
  }
}