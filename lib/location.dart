import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPage>
    with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();

  LatLng _shopLocation = const LatLng(9.9312, 76.2673);
  double _deliveryRadius = 15000;

  LatLng _currentCameraPosition = const LatLng(9.9312, 76.2673);
  double _currentZoom = 14.0;
  bool _isServiceable = true;
  bool _isLoading = true;
  bool _isMapMoving = false;
  String _detectedAddress = "Locating...";

  bool _isPinningMode = true;
  String _selectedLabel = "Home";

  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final Color _accentPink = const Color(0xFFFF2E74);

  final String _lightMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#f5f5f5"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#f5f5f5"}]},
    {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#eeeeee"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
    {"featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#dadada"}]},
    {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
    {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#c9c9c9"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _initializeData();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _nameController.dispose();
    _houseController.dispose();
    _landmarkController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userPhone = user.phoneNumber ?? "";

      String userName = "";
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        userName = user.displayName!;
      } else if (user.email != null && user.email!.isNotEmpty) {
        userName = user.email!.split('@')[0];
      }

      String enteredPhone = _phoneController.text.replaceAll(
        RegExp(r'[^0-9+]'),
        '',
      );
      String registeredPhone = userPhone.replaceAll(RegExp(r'[^0-9+]'), '');

      if (registeredPhone.isNotEmpty) {
        bool isSameNumber =
            (enteredPhone == registeredPhone) ||
            (enteredPhone.length >= 10 &&
                registeredPhone.endsWith(enteredPhone));

        if (isSameNumber) {
          if (_nameController.text != userName) {
            _nameController.text = userName;
          }
        } else {
          if (_nameController.text == userName) {
            _nameController.clear();
          }
        }
      }
    }
    setState(() {});
  }

  Future<void> _initializeData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('delivery_zone')
          .get()
          .timeout(const Duration(seconds: 4));
      if (doc.exists) {
        _shopLocation = LatLng(doc['lat'], doc['lng']);
        _deliveryRadius = doc['radius'].toDouble();
      }
    } catch (e) {
      debugPrint("Admin sync failed: $e");
    }

    try {
      await _locateUser().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint("Locating user failed: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _locateUser() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng userPos = LatLng(position.latitude, position.longitude);

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(userPos, 20.0));

      _updateMetrics(userPos, 20.0);
      _decodeAddress(userPos);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _goToShopZone() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_shopLocation, 13.0));
    _updateMetrics(_shopLocation, 13.0);
  }

  void _onCameraMove(CameraPosition position) {
    if (!_isPinningMode) return;
    if (!_isMapMoving) setState(() => _isMapMoving = true);

    _currentCameraPosition = position.target;
    _currentZoom = position.zoom;
  }

  void _onCameraIdle() {
    if (!_isPinningMode) return;
    setState(() => _isMapMoving = false);
    HapticFeedback.selectionClick();
    _updateMetrics(_currentCameraPosition, _currentZoom);
    _decodeAddress(_currentCameraPosition);
  }

  void _updateMetrics(LatLng pos, double zoom) {
    double distance = Geolocator.distanceBetween(
      _shopLocation.latitude,
      _shopLocation.longitude,
      pos.latitude,
      pos.longitude,
    );
    setState(() {
      _isServiceable = distance <= _deliveryRadius;
      _currentZoom = zoom;
    });
  }

  Future<void> _decodeAddress(LatLng pos) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String title = place.name ?? "";
        String sub = place.subLocality ?? "";
        String city = place.locality ?? "";
        String address = [
          title,
          sub,
          city,
        ].where((e) => e.isNotEmpty).toSet().join(", ");

        setState(() {
          _detectedAddress = address;
          _areaController.text = [
            sub,
            city,
          ].where((e) => e.isNotEmpty).join(", ");
        });
      }
    } catch (e) {}
  }

  void _showSavedAddressesSheet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to view saved addresses")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "SAVED ADDRESSES",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('addresses')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF2E74),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off_rounded,
                              size: 50,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "No saved addresses yet.",
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 30),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;

                        String label = data['label'] ?? 'Other';
                        IconData labelIcon = Icons.location_on_rounded;
                        if (label == 'Home') labelIcon = Icons.home_rounded;
                        if (label == 'Work') labelIcon = Icons.work_rounded;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.pop(context, {
                                    'address': data['fullAddress'],
                                    'lat': data['latitude'],
                                    'lng': data['longitude'],
                                    'link': data['googleMapsLink'],
                                    'phone': data['receiverPhone'],
                                    'name': data['receiverName'],
                                    'label': data['label'] ?? 'Other',
                                  });
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        labelIcon,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black87,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  label.toUpperCase(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  data['receiverName'] ??
                                                      'Name',
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            data['fullAddress'] ?? '',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            data['receiverPhone'] ?? '',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red[400],
                                size: 22,
                              ),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('addresses')
                                    .doc(doc.id)
                                    .delete();
                              },
                            ),
                          ],
                        );
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _accentPink)),
      );
    }

    bool isZoomedDeep = _currentZoom >= 17.0;
    bool canPickLocation = _isServiceable && isZoomedDeep;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCameraPosition,
              zoom: 18,
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(10, 22),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            scrollGesturesEnabled: _isPinningMode,
            zoomGesturesEnabled: _isPinningMode,
            tiltGesturesEnabled: false,
            onMapCreated: (controller) {
              _controller.complete(controller);
              controller.setMapStyle(_lightMapStyle);
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            circles: {
              Circle(
                circleId: const CircleId("delivery_zone"),
                center: _shopLocation,
                radius: _deliveryRadius,
                fillColor: _accentPink.withOpacity(0.05),
                strokeColor: _accentPink.withOpacity(0.3),
                strokeWidth: 1,
              ),
            },
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: 50,
            left: 20,
            child: _buildGlassBtn(Icons.arrow_back_ios_new, () {
              if (!_isPinningMode) {
                setState(() => _isPinningMode = true);
              } else {
                Navigator.pop(context);
              }
            }),
          ),

          if (_isPinningMode)
            Positioned(
              top: 50,
              right: 20,
              child: Row(
                children: [
                  _buildGlassBtn(
                    Icons.bookmarks_rounded,
                    _showSavedAddressesSheet,
                    label: "Saved",
                  ),
                  const SizedBox(width: 8),
                  _buildGlassBtn(Icons.storefront_rounded, _goToShopZone),
                  const SizedBox(width: 8),
                  _buildGlassBtn(
                    Icons.my_location_rounded,
                    _locateUser,
                    color: _accentPink,
                  ),
                ],
              ),
            ),

          if (_isPinningMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(
                    0,
                    _isMapMoving ? -15 : 0,
                    0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isMapMoving ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Release to pick",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Icon(
                        Icons.location_on,
                        size: 50,
                        color: _isServiceable ? _accentPink : Colors.grey,
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 6,
                        width: _isMapMoving ? 6 : 12,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutQuart,
              switchOutCurve: Curves.easeInQuart,
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
              child: _isPinningMode
                  ? _buildPinningPanel(canPickLocation, isZoomedDeep)
                  : _buildDetailsPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinningPanel(bool canPick, bool isZoomedDeep) {
    String statusText = "CONFIRM LOCATION";
    Color btnColor = _accentPink;
    IconData btnIcon = Icons.check_circle_outline;

    if (!_isServiceable) {
      statusText = "OUT OF DELIVERY ZONE";
      btnColor = Colors.redAccent;
      btnIcon = Icons.block;
    } else if (!isZoomedDeep) {
      statusText = "ZOOM IN CLOSER";
      btnColor = Colors.orangeAccent;
      btnIcon = Icons.zoom_in;
    }

    return Container(
      key: const ValueKey("PinningPanel"),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: _isServiceable ? _accentPink : Colors.grey,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DETECTED LOCATION",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _detectedAddress,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: canPick
                  ? () {
                      setState(() => _isPinningMode = false);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                disabledBackgroundColor: btnColor.withOpacity(0.2),
                disabledForegroundColor: btnColor,
                elevation: canPick ? 5 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(btnIcon, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    statusText,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return Container(
      key: const ValueKey("DetailsPanel"),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Text(
            "DELIVERY DETAILS",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildInput(
                  _houseController,
                  "House / Flat No.",
                  Icons.home_rounded,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildInput(
                  _areaController,
                  "Area / Locality",
                  Icons.map_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildInput(
            _landmarkController,
            "Landmark (Optional)",
            Icons.flag_rounded,
          ),
          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                flex: 5,
                child: _buildInput(
                  _phoneController,
                  "Receiver's Number",
                  Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 10),

              if (_phoneController.text.isEmpty)
                Expanded(
                  flex: 4,
                  child: TextButton.icon(
                    onPressed: () {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null &&
                          user.phoneNumber != null &&
                          user.phoneNumber!.isNotEmpty) {
                        _phoneController.text = user.phoneNumber!;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "No phone number linked to this login account.",
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.person, size: 16),
                    label: Text(
                      "Same Number",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _accentPink,
                      backgroundColor: _accentPink.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  flex: 5,
                  child: _buildInput(
                    _nameController,
                    "Receiver's Name",
                    Icons.person_outline_rounded,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            "SAVE AS",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildLabelChip("Home", Icons.home_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _buildLabelChip("Work", Icons.work_rounded)),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLabelChip("Other", Icons.location_on_rounded),
              ),
            ],
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _confirmAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                "SAVE ADDRESS",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelChip(String label, IconData icon) {
    bool isSelected = _selectedLabel == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedLabel = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.grey[200]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassBtn(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.black87,
    String? label,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: label != null
            ? const EdgeInsets.symmetric(horizontal: 16)
            : null,
        width: label != null ? null : 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: Colors.black87, fontSize: 14),
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 18),
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _confirmAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please Login to Save Address")),
      );
      return;
    }

    final String house = _houseController.text.trim();
    final String area = _areaController.text.trim();
    final String landmark = _landmarkController.text.trim();
    final String phone = _phoneController.text.trim();
    final String name = _nameController.text.trim();

    if (house.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter House/Flat Number")),
      );
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Receiver's Phone Number")),
      );
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Receiver's Name")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF2E74)),
      ),
    );

    try {
      String fullAddress = "$house, $area";
      if (landmark.isNotEmpty) fullAddress += " ($landmark)";

      final String googleMapsLink =
          "https://www.google.com/maps/search/?api=1&query=${_currentCameraPosition.latitude},${_currentCameraPosition.longitude}";
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .add({
            'userEmail': user.email,
            'fullAddress': fullAddress,
            'house': house,
            'area': area,
            'landmark': landmark,
            'receiverPhone': phone,
            'receiverName': name,
            'label': _selectedLabel,
            'latitude': _currentCameraPosition.latitude,
            'longitude': _currentCameraPosition.longitude,
            'googleMapsLink': googleMapsLink,
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'Map Selection',
          });

      if (mounted) Navigator.pop(context);

      if (mounted)
        Navigator.pop(context, {
          'address': fullAddress,
          'lat': _currentCameraPosition.latitude,
          'lng': _currentCameraPosition.longitude,
          'link': googleMapsLink,
          'phone': phone,
          'name': name,
          'label': _selectedLabel,
        });
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save address: $e")));
    }
  }
}
