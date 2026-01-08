import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const ProfitMateApp(),
    ),
  );
}

// ================== 1. MODEL DATA (Sesuai Excel) ==================

class MaterialItem {
  String id;
  String name;
  String supplier;
  double totalCost;
  double quantity; // Jumlah beli (misal 1000 gram)
  String unit; // Satuan (misal gram, pcs, ml)

  MaterialItem({
    required this.id,
    required this.name,
    required this.supplier,
    required this.totalCost,
    required this.quantity,
    required this.unit,
  });

  // Menghitung Harga Per Satuan (Rumus Excel: Total Cost / Qty)
  double get pricePerUnit => (quantity > 0) ? totalCost / quantity : 0.0;
}

class UsedMaterial {
  MaterialItem material;
  double usedQty;

  UsedMaterial({required this.material, required this.usedQty});

  // Biaya pemakaian = Harga Satuan x Jumlah Pakai
  double get cost => material.pricePerUnit * usedQty;
}

// ================== 2. LOGIC PROVIDER (Otak Aplikasi) ==================

class AppProvider with ChangeNotifier {
  // Database Bahan (In-Memory untuk Prototype)
  final List<MaterialItem> _materials = [
    MaterialItem(id: 'KN-1911', name: 'Beans Kopi', supplier: 'Rostery', totalCost: 150000, quantity: 1000, unit: 'gram'),
    MaterialItem(id: 'KT-8091', name: 'Susu Greenfield', supplier: 'Minimarket', totalCost: 25000, quantity: 1000, unit: 'ml'),
    MaterialItem(id: 'BW-1912', name: 'Cup Hot Kopi', supplier: 'Plastik Class', totalCost: 800, quantity: 1, unit: 'pcs'),
    MaterialItem(id: 'GL-001', name: 'Gula Aren', supplier: 'Pasar', totalCost: 15000, quantity: 500, unit: 'ml'),
  ];

  List<MaterialItem> get materials => _materials;

  // Variabel Kalkulator
  final List<UsedMaterial> _currentRecipe = [];
  double _laborCost = 0;
  double _packagingCost = 0;
  double _shippingCost = 0;
  double _markupPercent = 30; // Default 30%
  double _taxPercent = 0;

  List<UsedMaterial> get currentRecipe => _currentRecipe;
  double get laborCost => _laborCost;
  double get packagingCost => _packagingCost;
  double get shippingCost => _shippingCost;
  double get markupPercent => _markupPercent;
  double get taxPercent => _taxPercent;

  // --- Actions ---

  void addMaterial(MaterialItem item) {
    _materials.add(item);
    notifyListeners();
  }

  void addToRecipe(MaterialItem item, double qty) {
    _currentRecipe.add(UsedMaterial(material: item, usedQty: qty));
    notifyListeners();
  }

  void removeRecipeItem(int index) {
    _currentRecipe.removeAt(index);
    notifyListeners();
  }

  void updateCosts({double? labor, double? pack, double? ship, double? markup, double? tax}) {
    if (labor != null) _laborCost = labor;
    if (pack != null) _packagingCost = pack;
    if (ship != null) _shippingCost = ship;
    if (markup != null) _markupPercent = markup;
    if (tax != null) _taxPercent = tax;
    notifyListeners();
  }

  void resetCalculator() {
    _currentRecipe.clear();
    _laborCost = 0;
    _packagingCost = 0;
    _shippingCost = 0;
    notifyListeners();
  }

  // --- Perhitungan Akhir (Sesuai Rumus Excel) ---

  double get totalMaterialCost => _currentRecipe.fold(0, (sum, item) => sum + item.cost);
  
  // Total Base Cost (HPP)
  double get totalBaseCost => totalMaterialCost + _laborCost + _packagingCost + _shippingCost;

  // Harga Sebelum Pajak (Base Cost + Markup)
  double get preTaxPrice => totalBaseCost * (1 + (_markupPercent / 100));

  // Profit (Uang)
  double get profitAmount => preTaxPrice - totalBaseCost;

  // Harga Final (Termasuk Pajak)
  double get finalPrice => preTaxPrice * (1 + (_taxPercent / 100));
}

// ================== 3. USER INTERFACE (UI) ==================

class ProfitMateApp extends StatelessWidget {
  const ProfitMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profit Mate',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
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
  final List<Widget> _pages = [
    const CalculatorScreen(),
    const MaterialListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate), label: 'Kalkulator Harga'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Data Bahan'),
        ],
      ),
    );
  }
}

// --- SCREEN 1: KALKULATOR HARGA ---

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Kita gunakan Consumer di root build agar update state lebih aman
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Kalkulator Harga Jual'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.resetCalculator(),
                tooltip: "Reset",
              )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Bahan Baku
                _buildSectionTitle("1. Komposisi Bahan (Recipe)"),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        if (provider.currentRecipe.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Belum ada bahan. Klik tombol di bawah.", style: TextStyle(color: Colors.grey)),
                          ),
                        ...provider.currentRecipe.asMap().entries.map((entry) {
                          int idx = entry.key;
                          UsedMaterial item = entry.value;
                          return ListTile(
                            title: Text(item.material.name),
                            subtitle: Text("${item.usedQty} ${item.material.unit} x ${currency.format(item.material.pricePerUnit)}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(currency.format(item.cost), style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => provider.removeRecipeItem(idx),
                                )
                              ],
                            ),
                          );
                        }).toList(),
                        const Divider(),
                        ElevatedButton.icon(
                          onPressed: () => _showAddMaterialDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text("Tambah Bahan dari Stok"),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Section 2: Biaya Lain & Markup
                _buildSectionTitle("2. Biaya Operasional & Target"),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildNumberInput("Biaya Tenaga Kerja (Labor)", provider.laborCost, (val) => provider.updateCosts(labor: val)),
                        _buildNumberInput("Biaya Kemasan (Packaging)", provider.packagingCost, (val) => provider.updateCosts(pack: val)),
                        _buildNumberInput("Biaya Lain (Shipping/Listrik)", provider.shippingCost, (val) => provider.updateCosts(ship: val)),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Text("Markup Keuntungan (%)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: provider.markupPercent.toString(), // Fix: Pakai initialValue dari provider
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(suffixText: "%"),
                                onChanged: (val) => provider.updateCosts(markup: double.tryParse(val) ?? 0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Section 3: HASIL PERHITUNGAN
                _buildSectionTitle("3. Hasil Perhitungan"),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.teal.shade700, Colors.teal.shade400]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(blurRadius: 10, color: Colors.teal.withOpacity(0.3))]
                  ),
                  child: Column(
                    children: [
                      _buildResultRow("Total Base Cost (HPP)", provider.totalBaseCost, currency, isWhite: true),
                      _buildResultRow("Potensi Profit", provider.profitAmount, currency, isWhite: true),
                      const Divider(color: Colors.white54),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("HARGA JUAL REKOMENDASI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(currency.format(provider.preTaxPrice), style: const TextStyle(color: Colors.yellowAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
    );
  }

  Widget _buildNumberInput(String label, double currentVal, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: currentVal == 0 ? '' : currentVal.toString(),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixText: "Rp ",
          isDense: true,
        ),
        onChanged: (val) => onChanged(double.tryParse(val) ?? 0),
      ),
    );
  }

  Widget _buildResultRow(String label, double value, NumberFormat fmt, {bool isWhite = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isWhite ? Colors.white70 : Colors.black87)),
          Text(fmt.format(value), style: TextStyle(color: isWhite ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddMaterialDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) { // ctx adalah context milik BottomSheet
        return Consumer<AppProvider>(
          builder: (context, provider, _) {
            return Container(
               padding: const EdgeInsets.all(10),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Padding(
                     padding: EdgeInsets.all(8.0),
                     child: Text("Pilih Bahan Baku", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   ),
                   Expanded(
                     child: ListView.builder(
                      itemCount: provider.materials.length,
                      itemBuilder: (context, i) {
                        final item = provider.materials[i];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text("Stok: ${item.quantity} ${item.unit}"),
                          trailing: const Icon(Icons.add_circle_outline, color: Colors.teal),
                          onTap: () {
                            // FIX: Tutup bottom sheet dulu
                            Navigator.pop(ctx); 
                            // Lalu panggil dialog berikutnya dengan context 'context' (parent) yang aman
                            // Gunakan Future.delayed agar transisi UI selesai dulu
                            Future.delayed(const Duration(milliseconds: 100), () {
                               if (context.mounted) {
                                 _showQtyDialog(context, item);
                               }
                            });
                          },
                        );
                      },
                                     ),
                   ),
                 ],
               ),
            );
          },
        );
      },
    );
  }

  void _showQtyDialog(BuildContext parentContext, MaterialItem item) {
    final qtyController = TextEditingController();
    showDialog(
      context: parentContext,
      builder: (dialogCtx) => AlertDialog( // dialogCtx adalah context milik Dialog
        title: Text("Pakai ${item.name}"),
        content: TextField(
          controller: qtyController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: "Jumlah pemakaian (${item.unit})"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              double qty = double.tryParse(qtyController.text) ?? 0;
              if (qty > 0) {
                // FIX: Gunakan dialogCtx (context lokal) untuk mencari Provider
                // Karena dialogCtx adalah anak dari MaterialApp -> Provider
                Provider.of<AppProvider>(dialogCtx, listen: false).addToRecipe(item, qty);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text("Tambahkan"),
          )
        ],
      ),
    );
  }
}

// --- SCREEN 2: DATA BAHAN (INVENTORY) ---

class MaterialListScreen extends StatelessWidget {
  const MaterialListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Database Bahan Baku')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMaterialForm(context),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: provider.materials.length,
        itemBuilder: (ctx, i) {
          final item = provider.materials[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: CircleAvatar(child: Text(item.name[0])),
              title: Text(item.name),
              subtitle: Text("Supplier: ${item.supplier}\nBeli: ${currency.format(item.totalCost)} / ${item.quantity} ${item.unit}"),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Harga Satuan", style: TextStyle(fontSize: 10)),
                  Text(
                    "${currency.format(item.pricePerUnit)}/${item.unit}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddMaterialForm(BuildContext context) {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: "gram"); // default

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tambah Material Baru"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nama Bahan")),
              TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Total Harga Beli (Rp)")),
              Row(
                children: [
                  Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Qty Beli"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: "Satuan (kg/pcs)"))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && costCtrl.text.isNotEmpty) {
                final newItem = MaterialItem(
                  id: DateTime.now().toString(),
                  name: nameCtrl.text,
                  supplier: "-",
                  totalCost: double.tryParse(costCtrl.text) ?? 0,
                  quantity: double.tryParse(qtyCtrl.text) ?? 1,
                  unit: unitCtrl.text,
                );
                Provider.of<AppProvider>(context, listen: false).addMaterial(newItem);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Simpan"),
          )
        ],
      ),
    );
  }
}