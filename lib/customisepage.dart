import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

// --- 🎨 LUXURY PALETTE ---
const Color kPrimary = Color(0xFFAC5D76);      
const Color kPrimaryLight = Color(0xFFE8D3DA); 
const Color kBackground = Color(0xFFFAFAF8);   
const Color kSurface = Colors.white;           
const Color kTextDark = Color(0xFF2D2426);     
const Color kTextLight = Color(0xFF887A7D);    
const Color kGold = Color(0xFFC5A059);         
const Color kError = Color(0xFFD32F2F);

// --- API KEYS ---
const String kGeminiApiKey = "AIzaSyBH5r5_34eRS7ksgLhOZQKAT1xj7lQxzmU"; // Your Gemini Key
const String kOpenAIKey = "YOUR_OPENAI_KEY"; // Optional: For Image Gen

// --- DATA MODEL ---
class DraggableItem {
  String id;
  String name;
  String imagePath; 
  Offset position;  

  DraggableItem({
    required this.id, 
    required this.name, 
    required this.imagePath, 
    required this.position,
  });
}

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Butter Hearts Cakes',
    home: Customisepage(),
  ));
}

class Customisepage extends StatefulWidget {
  const Customisepage({super.key});

  @override
  State<Customisepage> createState() => _CakeCustomizationPageState();
}

class _CakeCustomizationPageState extends State<Customisepage> {
  late GenerativeModel _model;
  
  // --- State ---
  int layers = 3;
  String selectedShape = 'Round';
  Color selectedFrostingColor = const Color(0xFFFFFDD0);
  String selectedFrostingColorName = 'French Cream';
  bool showTopView = false;
  
  // Draggables
  List<DraggableItem> placedToppings = [];
  
  // Wish Text
  String wishText = "";
  Offset wishTextPosition = const Offset(0, 0);
  
  // Logic
  bool isDraggingAnyItem = false;
  bool isHoveringDelete = false;

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _wishController = TextEditingController();

  // AI
  String aiDescription = "";
  bool isGeneratingDescription = false;
  bool isGeneratingImage = false;

  // --- Data ---
  final List<Map<String, dynamic>> shapes = [
    {'name': 'Round', 'icon': Icons.circle_outlined},
    {'name': 'Square', 'icon': Icons.crop_square},
    {'name': 'Heart', 'icon': Icons.favorite_border},
  ];

  final List<Map<String, dynamic>> frostingColors = [
    {'name': 'French Cream', 'color': const Color(0xFFFFFDD0)},
    {'name': 'Pure White', 'color': Colors.white},
    {'name': 'Rose Petal', 'color': const Color(0xFFFFC1CC)},
    {'name': 'Duck Egg', 'color': const Color(0xFFD1E7F3)},
    {'name': 'Sage', 'color': const Color(0xFFD4E0D6)},
    {'name': 'Lavender', 'color': const Color(0xFFE6E6FA)},
    {'name': 'Cocoa', 'color': const Color(0xFF6D4C41)},
  ];

  final Map<String, Color> flavorColors = {
    'Vanilla Bean': const Color(0xFFFFF8E1),
    'Belgian Choco': const Color(0xFF4E342E),
    'Strawberry': const Color(0xFFEF9A9A),
    'Red Velvet': const Color(0xFFC62828),
    'Blueberry': const Color(0xFF5C6BC0),
  };

  late List<String> flavorKeys;
  List<String> selectedFlavors = List.generate(8, (_) => 'Vanilla Bean');

 // 🟢 DATA: Using Local Assets
  final List<Map<String, String>> toppingsList = [
    {'name': 'chocoball2', 'path': 'choco2.png'},
    {'name': 'Chocoball2', 'path': 'choco1.png'},
    {'name': 'fererro', 'path': 'ferrero.png'},
    {'name': 'Sprinkles', 'path': 'spri.png'},                  
    {'name': 'Cherry', 'path': 'cherry.png'},
    {'name': 'Toping', 'path': 'flower2.png'},
  ];



  @override
  void initState() {
    super.initState();
    flavorKeys = flavorColors.keys.toList();
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: kGeminiApiKey);
  }

  // --- LOGIC ---
  void updateLayers(int delta) {
    int newValue = layers + delta;
    if (newValue < 3 || newValue > 7) return;
    setState(() => layers = newValue);
  }

  void addTopping(String name, String path) {
    setState(() {
      showTopView = true;
      placedToppings.add(DraggableItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        imagePath: path,
        position: const Offset(0, 0),
      ));
    });
  }

  bool _checkIfOverTrash(Offset position) {
    return position.dy > 120; 
  }

  void _handleDelete(dynamic item) {
    setState(() {
      if (item is DraggableItem) {
        placedToppings.remove(item);
      } else if (item == 'text') {
        wishText = "";
        _wishController.clear();
        wishTextPosition = const Offset(0, 0);
      }
      isDraggingAnyItem = false;
      isHoveringDelete = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Item Removed"), duration: Duration(milliseconds: 500), backgroundColor: kError)
    );
  }

  // --- AI ---
  Future<void> _generateAIDescription() async {
    setState(() => isGeneratingDescription = true);
    try {
      final prompt = "Describe a luxury $layers-layer $selectedShape cake. "
          "Finish: $selectedFrostingColorName. Message: '$wishText'. "
          "Toppings: ${placedToppings.map((e) => e.name).toSet().join(', ')}. "
          "One sentence, appetizing, elegant.";
      final response = await _model.generateContent([Content.text(prompt)]);
      if (mounted) setState(() => aiDescription = response.text ?? "A masterpiece.");
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => isGeneratingDescription = false);
    }
  }

  Future<void> _generateRealisticImage() async {
    if (kOpenAIKey == "YOUR_OPENAI_KEY") {
       _showImageDialog("https://placehold.co/1024x1024/png?text=Add+API+Key"); 
       return;
    }
    setState(() => isGeneratingImage = true);
    try {
      String prompt = "Professional food photography of a $selectedShape cake. "
          "$layers layers, $selectedFrostingColorName frosting. "
          "Text '$wishText' written in cursive icing. "
          "Topped with ${placedToppings.map((e) => e.name).join(', ')}. "
          "Soft lighting, 8k, top-down view.";

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/images/generations'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $kOpenAIKey'},
        body: jsonEncode({"model": "dall-e-3", "prompt": prompt, "n": 1, "size": "1024x1024"}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) _showImageDialog(data['data'][0]['url']);
      }
    } catch (e) {
      // Handle
    } finally {
      if (mounted) setState(() => isGeneratingImage = false);
    }
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(borderRadius: BorderRadius.circular(25), child: Stack(children: [Image.network(url, fit: BoxFit.cover, height: 400, width: double.infinity), Positioned(top: 10, right: 10, child: CircleAvatar(backgroundColor: Colors.black45, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))))])),
      ),
    );
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('BUTTER HEARTS CAKES', style: TextStyle(color: kTextDark, fontFamily: 'Serif', fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
        backgroundColor: kBackground,
        elevation: 0,
        centerTitle: true,
        leading: const Icon(Icons.short_text, color: kTextDark, size: 30),
        actions: [IconButton(icon: const Icon(Icons.auto_awesome_outlined, color: kPrimary), onPressed: () => _showAIChat(context))],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShowcaseVisualizer(),
            const SizedBox(height: 35),
            
            _buildSectionHeader("STRUCTURAL SHAPE"),
            _buildModernShapeSelector(),
            
            const SizedBox(height: 35),
            _buildSectionHeader("LAYER"),
            _buildLayerAndColorRow(),
            
            const SizedBox(height: 35),
            _buildSectionHeader("INTERIOR FLAVORS"),
            _buildFlavorList(),
            
            const SizedBox(height: 35),
            _buildSectionHeader("WRITE A WISH"),
            _buildWishInput(),

            const SizedBox(height: 35),
            _buildSectionHeader("ADD GARNISH (Drag to Move)"),
            _buildToppingsSelector(),
            
            const SizedBox(height: 35),
            _buildSectionHeader("CHEF'S NOTES"),
            _buildNotesInput(),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  // --- VISUALIZER ---
  Widget _buildShowcaseVisualizer() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 360, width: double.infinity,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 15))],
            gradient: RadialGradient(colors: [Colors.white, kBackground], center: Alignment.center, radius: 0.8)
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      switchInCurve: Curves.easeInOutBack,
                      child: showTopView ? _buildInteractiveTopView() : _buildSideView(),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isDraggingAnyItem ? 0.0 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [_buildToggleBtn("Profile", !showTopView), _buildToggleBtn("Overhead", showTopView)]),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        if (isDraggingAnyItem)
          Positioned(
            bottom: 20,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isHoveringDelete ? 1.2 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: isHoveringDelete ? kError : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                child: Icon(Icons.delete_outline, color: isHoveringDelete ? Colors.white : kError, size: 28),
              ),
            ),
          ),

        if (!isDraggingAnyItem) ...[
          Positioned(right: 20, top: 20, child: FloatingActionButton.small(heroTag: 'ai_gen', backgroundColor: kTextDark, elevation: 2, onPressed: isGeneratingImage ? null : _generateRealisticImage, child: isGeneratingImage ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.camera, color: Colors.white, size: 18))),
          Positioned(top: 20, left: 20, child: GestureDetector(onTap: _generateAIDescription, child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: isGeneratingDescription ? kPrimary : Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Row(children: [Icon(Icons.auto_awesome, size: 16, color: isGeneratingDescription ? Colors.white : kPrimary), const SizedBox(width: 8), Text(isGeneratingDescription ? "Designing..." : "Ask Butter", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isGeneratingDescription ? Colors.white : kTextDark))]))))
        ]
      ],
    );
  }

  // --- VIEWS ---
  Widget _buildSideView() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(width: 160, height: 15, decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), boxShadow: [BoxShadow(color: kTextDark.withOpacity(0.15), blurRadius: 25, offset: const Offset(0, 10))])),
        Column(mainAxisSize: MainAxisSize.min, children: List.generate(layers, (index) => _build3DLayer(selectedFrostingColor)).reversed.toList()),
        if(placedToppings.isNotEmpty || wishText.isNotEmpty)
          Positioned(top: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(10)), child: const Text("Decorations on Top", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))
      ],
    );
  }
Widget _buildInteractiveTopView() {
    double size = 200;
    
    Widget cakeBase = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: selectedFrostingColor,
        shape: selectedShape == 'Round' ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: selectedShape == 'Square' ? BorderRadius.circular(25) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 0, spreadRadius: -2, offset: const Offset(-3, -3))
        ]
      ),
    );

    Widget clippedBase = cakeBase;
    if (selectedShape == 'Heart') {
      clippedBase = ClipPath(clipper: ImprovedHeartClipper(), child: cakeBase);
    }

    return SizedBox(
      width: size, height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          clippedBase,
          
          // DRAGGABLE WISH TEXT
          if (wishText.isNotEmpty)
            Positioned(
              left: (size / 2) + wishTextPosition.dx - 50, 
              top: (size / 2) + wishTextPosition.dy - 10,
              child: GestureDetector(
                onPanStart: (_) => setState(() => isDraggingAnyItem = true),
                onPanUpdate: (details) {
                  setState(() {
                    wishTextPosition += details.delta;
                    isHoveringDelete = _checkIfOverTrash(wishTextPosition);
                  });
                },
                onPanEnd: (_) {
                  if (_checkIfOverTrash(wishTextPosition)) {
                    _handleDelete('text');
                  } else {
                    setState(() { isDraggingAnyItem = false; isHoveringDelete = false; });
                  }
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    wishText, 
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dancingScript(
                      fontSize: 26, 
                      fontWeight: FontWeight.bold, 
                      color: kPrimary, 
                      shadows: [Shadow(color: Colors.white.withOpacity(0.8), offset: const Offset(1, 1), blurRadius: 0)]
                    )
                  ),
                ),
              ),
            ),

          // 🔥 DRAGGABLE TOPPINGS (Using Image.asset)
          ...placedToppings.map((item) {
            return Positioned(
              left: (size / 2) + item.position.dx - 22, 
              top: (size / 2) + item.position.dy - 22,
              child: GestureDetector(
                onPanStart: (_) => setState(() => isDraggingAnyItem = true),
                onPanUpdate: (details) {
                  setState(() {
                    item.position += details.delta;
                    isHoveringDelete = _checkIfOverTrash(item.position);
                  });
                },
                onPanEnd: (_) {
                  if (_checkIfOverTrash(item.position)) {
                    _handleDelete(item);
                  } else {
                    setState(() { isDraggingAnyItem = false; isHoveringDelete = false; });
                  }
                },
                // 🟢 CHANGED TO Image.asset
                child: Image.asset(
                  item.imagePath, 
                  width: 45, 
                  height: 45, 
                  errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 30, color: Colors.grey)
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
  Widget _build3DLayer(Color color) {
    double width = 200; double height = 40;
    LinearGradient satinGradient = LinearGradient(colors: [Color.lerp(color, Colors.black, 0.08)!, color, Color.lerp(color, Colors.white, 0.12)!, color, Color.lerp(color, Colors.black, 0.08)!], stops: const [0.0, 0.35, 0.5, 0.65, 1.0]);
    BorderRadius radius = selectedShape == 'Square' ? BorderRadius.circular(6) : BorderRadius.circular(15);
    if(selectedShape == 'Heart') return ClipPath(clipper: ImprovedHeartClipper(), child: Container(width: width, height: height, margin: EdgeInsets.zero, decoration: BoxDecoration(gradient: satinGradient)));
    return Container(width: width, height: height, margin: EdgeInsets.zero, decoration: BoxDecoration(gradient: satinGradient, borderRadius: radius));
  }

  // --- CONTROLS ---
  Widget _buildWishInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: kGold.withOpacity(0.5))),
      child: TextField(
        controller: _wishController,
        onChanged: (val) => setState(() { wishText = val; showTopView = true; }),
        style: const TextStyle(fontSize: 16, color: kTextDark, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(border: InputBorder.none, hintText: "e.g. Happy Birthday", hintStyle: TextStyle(color: kTextLight, fontSize: 14), icon: Icon(Icons.edit, color: kGold)),
      ),
    );
  }
Widget _buildToppingsSelector() {
    return Wrap(
      spacing: 12, runSpacing: 12,
      children: toppingsList.map((t) {
        return GestureDetector(
          onTap: () => addTopping(t['name']!, t['path']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: kTextDark.withOpacity(0.1)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🟢 CHANGED TO Image.asset
                Image.asset(
                  t['path']!, 
                  width: 25, 
                  height: 25, 
                  errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported, size: 20, color: Colors.grey)
                ),
                const SizedBox(width: 8),
                Text(t['name']!, style: const TextStyle(color: kTextDark, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.add_circle, size: 14, color: kPrimary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  // --- STANDARD HELPERS ---
  Widget _buildSectionHeader(String title) => Text(title, style: const TextStyle(color: kTextLight, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'Sans'));
  Widget _buildToggleBtn(String text, bool active) => GestureDetector(onTap: () => setState(() => showTopView = text == "Overhead"), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), decoration: BoxDecoration(color: active ? kTextDark : Colors.transparent, borderRadius: BorderRadius.circular(30)), child: Text(text, style: TextStyle(color: active ? Colors.white : kTextLight, fontWeight: FontWeight.bold, fontSize: 12))));
  Widget _buildModernShapeSelector() => Row(children: shapes.map((shape) { bool selected = selectedShape == shape['name']; return Expanded(child: GestureDetector(onTap: () => setState(() => selectedShape = shape['name']), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 15), height: 80, decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? kPrimary : Colors.transparent, width: 2), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(shape['icon'], color: selected ? kPrimary : kTextLight, size: 26), const SizedBox(height: 8), Text(shape['name'], style: TextStyle(color: selected ? kPrimary : kTextLight, fontSize: 12, fontWeight: FontWeight.bold))])))); }).toList());
  Widget _buildLayerAndColorRow() => Row(children: [Expanded(flex: 4, child: Container(height: 60, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(18)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_iconBtn(Icons.remove, () => updateLayers(-1)), Text("$layers Layers", style: const TextStyle(fontWeight: FontWeight.bold, color: kTextDark)), _iconBtn(Icons.add, () => updateLayers(1))]))), const SizedBox(width: 15), Expanded(flex: 6, child: SizedBox(height: 60, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: frostingColors.length, itemBuilder: (c, i) { final color = frostingColors[i]['color'] as Color; bool selected = selectedFrostingColor == color; return GestureDetector(onTap: () => setState(() { selectedFrostingColor = color; selectedFrostingColorName = frostingColors[i]['name']; }), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 45, height: 45, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: selected ? kPrimary : Colors.grey.shade200, width: selected ? 2.5 : 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]))); })))]);
  Widget _iconBtn(IconData icon, VoidCallback onTap) => IconButton(onPressed: onTap, icon: Icon(icon, size: 18, color: kTextDark), style: IconButton.styleFrom(backgroundColor: kBackground, padding: EdgeInsets.zero));
  Widget _buildFlavorList() => Column(children: List.generate(layers, (index) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16)), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: kPrimaryLight.withOpacity(0.3), borderRadius: BorderRadius.circular(8)), child: Text("Layer ${layers - index}", style: const TextStyle(fontSize: 11, color: kPrimary, fontWeight: FontWeight.bold))), const SizedBox(width: 20), Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: selectedFlavors[index], isExpanded: true, icon: const Icon(Icons.expand_more, size: 20, color: kTextLight), style: const TextStyle(color: kTextDark, fontSize: 15, fontWeight: FontWeight.w600), items: flavorKeys.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (val) => setState(() => selectedFlavors[index] = val!))))]))));
  Widget _buildNotesInput() => Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20)), child: TextField(controller: _notesController, maxLines: 3, style: const TextStyle(fontSize: 14, color: kTextDark), decoration: const InputDecoration(border: InputBorder.none, hintText: "Add allergies or inscription details...", hintStyle: TextStyle(color: kTextLight, fontSize: 14))));
  Widget _buildBottomBar() => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: kSurface, borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))]), child: SafeArea(child: Row(children: [Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("TOTAL ESTIMATE", style: TextStyle(color: kTextLight, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 4), Text("\$${(layers * 35) + (placedToppings.length * 8)}", style: const TextStyle(color: kTextDark, fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'Serif'))])), Expanded(flex: 2, child: ElevatedButton(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent to kitchen!"))); }, style: ElevatedButton.styleFrom(backgroundColor: kTextDark, foregroundColor: kGold, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 5, shadowColor: kTextDark.withOpacity(0.3)), child: const Text("REQUEST BOOKING", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))))])));
  void _showAIChat(BuildContext context) { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const ButterAIChatSheet()); }
}

// 🟢 4. FIXED HEART CLIPPER (Correct Math)
class ImprovedHeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double width = size.width;
    double height = size.height;
    
    path.moveTo(0.5 * width, height * 0.30);
    path.cubicTo(0.15 * width, height * 0.05, -0.2 * width, height * 0.6, 0.5 * width, height * 0.95);
    path.moveTo(0.5 * width, height * 0.30);
    path.cubicTo(0.85 * width, height * 0.05, 1.2 * width, height * 0.6, 0.5 * width, height * 0.95);
    
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class ButterAIChatSheet extends StatefulWidget {
  const ButterAIChatSheet({super.key});
  @override
  State<ButterAIChatSheet> createState() => _ButterAIChatSheetState();
}

class _ButterAIChatSheetState extends State<ButterAIChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [{'role': 'model', 'text': 'Bonjour! I am Butter. How may I assist with your exquisite design today?'}];
  bool _isLoading = false;
  late GenerativeModel _model;
  late ChatSession _chat;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: kGeminiApiKey);
    _chat = _model.startChat();
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;
    setState(() { _messages.add({'role': 'user', 'text': _controller.text}); _isLoading = true; });
    String userText = _controller.text; _controller.clear();
    try {
      final response = await _chat.sendMessage(Content.text(userText));
      setState(() { _messages.add({'role': 'model', 'text': response.text ?? "Error."}); });
    } catch (e) { setState(() { _messages.add({'role': 'model', 'text': "I seem to be unavailable."}); }); } 
    finally { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: kBackground, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), decoration: BoxDecoration(color: kSurface, borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Row(children: [const CircleAvatar(backgroundColor: kPrimary, child: Text("🧈")), const SizedBox(width: 15), const Text("Butter Concierge", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)), const Spacer(), IconButton(icon: const Icon(Icons.close, color: kTextLight), onPressed: () => Navigator.pop(context))])),
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(24), itemCount: _messages.length, itemBuilder: (context, index) { final msg = _messages[index]; bool isUser = msg['role'] == 'user'; return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), decoration: BoxDecoration(color: isUser ? kTextDark : kSurface, borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(isUser ? 20 : 0), bottomRight: Radius.circular(isUser ? 0 : 20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]), child: Text(msg['text']!, style: TextStyle(color: isUser ? kGold : kTextDark, height: 1.4))));})),
        if (_isLoading) const LinearProgressIndicator(color: kPrimary, backgroundColor: Colors.transparent, minHeight: 2),
        Container(padding: const EdgeInsets.fromLTRB(24, 10, 24, 40), color: kSurface, child: Row(children: [Expanded(child: TextField(controller: _controller, onSubmitted: (_) => _sendMessage(), decoration: InputDecoration(hintText: "Type your question...", hintStyle: TextStyle(color: kTextLight.withOpacity(0.5)), filled: true, fillColor: kBackground, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)))), const SizedBox(width: 12), FloatingActionButton(mini: true, onPressed: _sendMessage, backgroundColor: kTextDark, elevation: 0, child: const Icon(Icons.arrow_upward, color: kGold, size: 20))]))
      ]),
    );
  }
}