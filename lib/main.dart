import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Prefs dengan Error Handling
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    // Jika gagal init prefs (jarang terjadi), aplikasi tetap jalan
    debugPrint("Error init prefs: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider(prefs)),
      ],
      child: const ProfitMateApp(),
    ),
  );
}

// ================== 1. MODEL DATA (SUPER SAFE VERSION) ==================

// Fungsi helper super aman untuk konversi angka
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

  factory MaterialItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) return MaterialItem(id: '0', name: 'Error', supplier: '-', totalCost: 0, quantity: 1, unit: 'pcs');
    
    return MaterialItem(
      id: json['id']?.toString() ?? DateTime.now().toString(),
      name: json['name']?.toString() ?? 'Tanpa Nama',
      supplier: json['supplier']?.toString() ?? '-',
      totalCost: safeDouble(json['totalCost']),
      quantity: safeDouble(json['quantity']),
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

  factory UsedMaterial.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return UsedMaterial(
        material: MaterialItem(id: '0', name: 'Unknown', supplier: '-', totalCost: 0, quantity: 1, unit: 'pcs'),
        usedQty: 0
      );
    }
    return UsedMaterial(
      material: MaterialItem.fromJson(json['material']),
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

  factory SavedRecipe.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SavedRecipe(id: '0', name: 'Error', materials: [], laborCost: 0, packagingCost: 0, shippingCost: 0, markupPercent: 0);
    
    var matList = json['materials'] as List? ?? [];
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

// ================== 2. LOGIC PROVIDER (DENGAN SAFEGUARD) ==================

class AppProvider with ChangeNotifier {
  final SharedPreferences? prefs; // Bisa null
  
  List<MaterialItem> _materials = [];
  List<SavedRecipe> _savedRecipes = [];

  List<UsedMaterial> _currentRecipe = [];
  String _currentRecipeName = "Resep Baru";
  double _laborCost = 0;
  double _packagingCost = 0;
  double _shippingCost = 0;
  double _markupPercent = 30;

  AppProvider(this.prefs) {
    _loadFromPrefs();
  }

  List<MaterialItem> get materials => _materials;
  List<SavedRecipe> get savedRecipes => _savedRecipes;
  List<UsedMaterial> get currentRecipe => _currentRecipe;
  String get currentRecipeName => _currentRecipeName;
  double get laborCost => _laborCost;
  double get packagingCost => _packagingCost;
  double get shippingCost => _shippingCost;
  double get markupPercent => _markupPercent;

  // --- SAFE LOADING LOGIC ---
  void _loadFromPrefs() {
    if (prefs == null) return;

    // 1. Load Materials dengan Try-Catch
    try {
      String? matString = prefs!.getString('materials');
      if (matString != null && matString.isNotEmpty) {
        List<dynamic> jsonList = jsonDecode(matString);
        _materials = jsonList.map((e) => MaterialItem.fromJson(e)).toList();
      } else {
        _initDummyData();
      }
    } catch (e) {
      debugPrint("Data Material Rusak: $e");
      // JIKA RUSAK, HAPUS DAN RESET
      prefs!.remove('materials');
      _initDummyData();
    }

    // 2. Load Recipes dengan Try-Catch
    try {
      String? recString = prefs!.getString('recipes');
      if (recString != null && recString.isNotEmpty) {
        List<dynamic> jsonList = jsonDecode(recString);
        _savedRecipes = jsonList.map((e) => SavedRecipe.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Data Resep Rusak: $e");
      prefs!.remove('recipes');
      _savedRecipes = [];
    }
    
    notifyListeners();
  }

  void _initDummyData() {
    _materials = [
      MaterialItem(id: '1', name: 'Kopi Beans', supplier: 'Petani', totalCost: 150000, quantity: 1000, unit: 'gram'),
      MaterialItem(id: '2', name: 'Susu', supplier: 'Toko', totalCost: 24000, quantity: 1000, unit: 'ml'),
    ];
  }

  void _saveMaterialsToPrefs() {
    if (prefs == null) return;
    try {
      String jsonString = jsonEncode(_materials.map((e) => e.toJson()).toList());
      prefs!.setString('materials', jsonString);
    } catch (e) {
      debugPrint("Gagal simpan material: $e");
    }
  }

  void _saveRecipesToPrefs() {
    if (prefs == null) return;
    try {
      String jsonString = jsonEncode(_savedRecipes.map((e) => e.toJson()).toList());
      prefs!.setString('recipes', jsonString);
    } catch (e) {
      debugPrint("Gagal simpan resep: $e");
    }
  }

  // --- ACTIONS ---

  void addMaterial(MaterialItem item) {
    _materials.add(item);
    _saveMaterialsToPrefs();
    notifyListeners();
  }

  void deleteMaterial(int index) {
    if (index >= 0 && index < _materials.length) {
      _materials.removeAt(index);
      _saveMaterialsToPrefs();
      notifyListeners();
    }
  }

  void addToRecipe(MaterialItem item, double qty) {
    _currentRecipe.add(UsedMaterial(material: item, usedQty: qty));
    notifyListeners();
  }

  void removeRecipeItem(int index) {
    if (index >= 0 && index < _currentRecipe.length) {
      _currentRecipe.removeAt(index);
      notifyListeners();
    }
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
    // Deep copy materials agar tidak referensi memori yang sama
    _currentRecipe = recipe.materials.map((m) => UsedMaterial(
      material: m.material, 
      usedQty: m.usedQty
    )).toList();
    
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

    _savedRecipes.add(newRecipe);
    _saveRecipesToPrefs();
    notifyListeners();
  }

  void deleteSavedRecipe(int index) {
    if (index >= 0 && index < _savedRecipes.length) {
      _savedRecipes.removeAt(index);
      _saveRecipesToPrefs();
      notifyListeners();
    }
  }

  double get totalMaterialCost => _currentRecipe.fold(0, (sum, item) => sum + item.cost);
  double get totalBaseCost => totalMaterialCost + _laborCost + _packagingCost + _shippingCost;
  double get preTaxPrice => totalBaseCost * (1 + (_markupPercent / 100));
  double get profitAmount => preTaxPrice - totalBaseCost;
}

// ================== 3. UI (TETAP SAMA TAPI AMAN) ==================

class ProfitMateApp extends StatelessWidget {
  const ProfitMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profit Mate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal, 
        useMaterial3: true, 
        scaffoldBackgroundColor: Colors.grey[100]
      ),
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
              // Delay sedikit agar bottom sheet tutup dulu
              Future.delayed(const Duration(milliseconds: 100), () {
                 if (context.mounted) _inputQty(context, prov.materials[i]);
              });
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

// --- SCREEN 2: BUKU RESEP ---

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
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

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
            leading: CircleAvatar(child: Text(item.name.isNotEmpty ? item.name[0] : '?')),
            title: Text(item.name),
            subtitle: Text("Rp ${currency.format(item.totalCost)} / ${item.quantity} ${item.unit}"),
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