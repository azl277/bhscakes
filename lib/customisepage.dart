import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kPrimary = Color(0xFFAC5D76);
const Color kPrimaryLight = Color(0xFFFDEEF2);
const Color kBackground = Color(0xFFF9F9F7);
const Color kSurface = Colors.white;
const Color kTextDark = Color(0xFF1F1A1B);
const Color kTextLight = Color(0xFF9E8E91);
const Color kGold = Color(0xFFB38E44);
const Color kError = Color(0xFFE57373);

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

class Customisepage extends StatefulWidget {
  const Customisepage({super.key});

  @override
  State<Customisepage> createState() => _CustomisepageState();
}

class _CustomisepageState extends State<Customisepage> {
  int layers = 3;
  String selectedShape = 'Round';
  Color selectedFrostingColor = const Color(0xFFFFFDD0);
  bool showTopView = false;
  List<DraggableItem> placedToppings = [];
  String wishText = "";
  Offset wishTextPosition = Offset.zero;

  bool isDragging = false;
  bool isOverDelete = false;

  final TextEditingController _wishController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> shapes = [
    {'name': 'Round', 'icon': Icons.circle_outlined},
    {'name': 'Square', 'icon': Icons.crop_square},
    {'name': 'Heart', 'icon': Icons.favorite_border},
  ];

  final List<Map<String, dynamic>> frostingColors = [
    {'name': 'French Cream', 'color': const Color(0xFFFFFDD0)},
    {'name': 'Rose Petal', 'color': const Color(0xFFFFC1CC)},
    {'name': 'Lavender', 'color': const Color(0xFFE6E6FA)},
    {'name': 'Sage', 'color': const Color(0xFFD4E0D6)},
    {'name': 'Cocoa', 'color': const Color(0xFF6D4C41)},
  ];

  final List<String> flavorKeys = [
    'Vanilla Bean',
    'Belgian Choco',
    'Strawberry',
    'Red Velvet',
    'Blueberry',
  ];
  late List<String> selectedFlavors;

  final List<Map<String, String>> toppingsList = [
    {'name': 'Choco Ball', 'path': 'assets/choco1.png'},
    {'name': 'Ferrero', 'path': 'assets/ferrero.png'},
    {'name': 'Sprinkles', 'path': 'assets/spri.png'},
    {'name': 'Cherry', 'path': 'assets/cherry.png'},
    {'name': 'Flower', 'path': 'assets/flower2.png'},
  ];

  @override
  void initState() {
    super.initState();
    selectedFlavors = List.generate(10, (_) => 'Vanilla Bean');
  }

  void addTopping(String name, String path) {
    setState(() {
      showTopView = true;
      placedToppings.add(
        DraggableItem(
          id: DateTime.now().toString(),
          name: name,
          imagePath: path,
          position: Offset.zero,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? screenWidth * 0.1 : 20,
              vertical: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVisualizerContainer(constraints),
                const SizedBox(height: 30),
                _buildSectionTitle("CHOOSE BASE SHAPE"),
                _buildShapeSelector(),
                const SizedBox(height: 30),
                _buildLayerAndColorSection(),
                const SizedBox(height: 30),
                _buildSectionTitle("CUSTOM INSCRIPTION"),
                _buildWishInput(),
                const SizedBox(height: 30),
                _buildSectionTitle("TOPPINGS (DRAG TO ARRANGE)"),
                _buildToppingInventory(),
                const SizedBox(height: 30),
                _buildSectionTitle("FLAVOR PER LAYER"),
                _buildFlavorConfigurator(),
                const SizedBox(height: 120),
              ],
            ),
          );
        },
      ),
      bottomSheet: _buildPricingBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kBackground,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: Text(
        "BUTTER HEARTS",
        style: GoogleFonts.playfairDisplay(
          color: kTextDark,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: kTextDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildVisualizerContainer(BoxConstraints constraints) {
    return Container(
      width: double.infinity,
      height: 380,
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: showTopView ? _buildTopView() : _buildSideView(),
            ),
          ),
          Positioned(bottom: 20, child: _buildViewToggle()),
          if (isDragging) Positioned(top: 20, child: _buildDeleteZone()),
        ],
      ),
    );
  }

  Widget _buildSideView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(layers, (index) {
        return Container(
          width: 180 - (index * 5.0),
          height: 38,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: selectedFrostingColor,
            borderRadius: selectedShape == 'Square'
                ? BorderRadius.circular(4)
                : BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 4),
              ),
            ],
            gradient: LinearGradient(
              colors: [
                selectedFrostingColor,
                selectedFrostingColor.withOpacity(0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        );
      }).reversed.toList(),
    );
  }

  Widget _buildTopView() {
    double size = 220;
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildCakeShapeBase(size),

        if (wishText.isNotEmpty)
          Positioned(
            left: (size / 2) + wishTextPosition.dx - 60,
            top: (size / 2) + wishTextPosition.dy - 20,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                wishTextPosition += d.delta;
                isDragging = true;
                isOverDelete = wishTextPosition.dy < -100;
              }),
              onPanEnd: (_) => setState(() {
                if (isOverDelete) {
                  wishText = "";
                  _wishController.clear();
                }
                isDragging = false;
                isOverDelete = false;
              }),
              child: Text(
                wishText,
                style: GoogleFonts.dancingScript(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: kPrimary,
                ),
              ),
            ),
          ),

        ...placedToppings.map(
          (item) => Positioned(
            left: (size / 2) + item.position.dx - 20,
            top: (size / 2) + item.position.dy - 20,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                item.position += d.delta;
                isDragging = true;
                isOverDelete = item.position.dy < -100;
              }),
              onPanEnd: (_) => setState(() {
                if (isOverDelete) placedToppings.remove(item);
                isDragging = false;
                isOverDelete = false;
              }),
              child: Image.asset(item.imagePath, width: 40, height: 40),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCakeShapeBase(double size) {
    if (selectedShape == 'Heart') {
      return ClipPath(
        clipper: ImprovedHeartClipper(),
        child: Container(
          width: size,
          height: size,
          color: selectedFrostingColor,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selectedFrostingColor,
        shape: selectedShape == 'Round' ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: selectedShape == 'Square'
            ? BorderRadius.circular(20)
            : null,
      ),
    );
  }

  Widget _buildShapeSelector() {
    return Row(
      children: shapes.map((s) {
        bool isSelected = selectedShape == s['name'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => selectedShape = s['name']),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: isSelected ? kTextDark : kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? kTextDark : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    s['icon'],
                    color: isSelected ? Colors.white : kTextLight,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : kTextDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLayerAndColorSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("LAYERS"),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _qtyBtn(
                      Icons.remove,
                      () =>
                          setState(() => layers = layers > 1 ? layers - 1 : 1),
                    ),
                    Text(
                      "$layers",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _qtyBtn(
                      Icons.add,
                      () =>
                          setState(() => layers = layers < 8 ? layers + 1 : 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("FROSTING"),
              SizedBox(
                height: 45,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: frostingColors.map((c) {
                    bool isSelected = selectedFrostingColor == c['color'];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => selectedFrostingColor = c['color']),
                      child: Container(
                        width: 40,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: c['color'],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? kGold : Colors.black12,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToppingInventory() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: toppingsList.length,
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () =>
                addTopping(toppingsList[i]['name']!, toppingsList[i]['path']!),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Image.asset(toppingsList[i]['path']!, width: 40),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlavorConfigurator() {
    return Column(
      children: List.generate(layers, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedFlavors[index],
              isExpanded: true,
              items: flavorKeys
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => selectedFlavors[index] = v!),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPricingBottomBar() {
    int total = (layers * 450) + (placedToppings.length * 50);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: kSurface,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ESTIMATED PRICE",
                  style: TextStyle(fontSize: 10, color: kTextLight),
                ),
                Text(
                  "₹$total",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: kTextDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "PROCEED",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: kTextLight,
      ),
    ),
  );

  Widget _qtyBtn(IconData i, VoidCallback t) => IconButton(
    onPressed: t,
    icon: Icon(i, size: 16),
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    padding: EdgeInsets.zero,
  );

  Widget _buildViewToggle() => Container(
    decoration: BoxDecoration(
      color: kBackground,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      children: [
        _toggleItem("Side", !showTopView),
        _toggleItem("Top", showTopView),
      ],
    ),
  );

  Widget _toggleItem(String l, bool a) => GestureDetector(
    onTap: () => setState(() => showTopView = l == "Top"),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: a ? kTextDark : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        l,
        style: TextStyle(color: a ? Colors.white : kTextLight, fontSize: 12),
      ),
    ),
  );

  Widget _buildDeleteZone() => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isOverDelete ? kError : kError.withOpacity(0.2),
      shape: BoxShape.circle,
    ),
    child: Icon(
      Icons.delete_outline,
      color: isOverDelete ? Colors.white : kError,
    ),
  );

  Widget _buildWishInput() {
    return TextField(
      controller: _wishController,
      onChanged: (v) => setState(() {
        wishText = v;
        if (v.isNotEmpty) showTopView = true;
      }),
      decoration: InputDecoration(
        hintText: "Enter name or message...",
        filled: true,
        fillColor: kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class ImprovedHeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(size.width / 2, size.height * 0.35);
    path.cubicTo(
      0,
      size.height * 0.1,
      0,
      size.height * 0.8,
      size.width / 2,
      size.height,
    );
    path.cubicTo(
      size.width,
      size.height * 0.8,
      size.width,
      size.height * 0.1,
      size.width / 2,
      size.height * 0.35,
    );
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
