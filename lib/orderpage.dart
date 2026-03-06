import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class OngoingOrderPage extends StatefulWidget {
  final String orderId;

  const OngoingOrderPage({super.key, required this.orderId});

  @override
  State<OngoingOrderPage> createState() => _OngoingOrderPageState();
}

class _OngoingOrderPageState extends State<OngoingOrderPage> {
  final Color _accentPink = const Color(0xFFFF2E74);
  final Color _premiumBlack = const Color(0xFF1E1E1E);
  final Color _bgGrey = const Color(0xFFF5F7FA);
  final Color _successGreen = const Color(0xFF10B981);

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String _lastStatus = "";
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    if (kIsWeb) return;

    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidImplementation?.requestNotificationsPermission();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'bhs_orders_high_priority_v5',
        'Order Status Updates',
        description: 'Real-time updates for your cake orders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation?.createNotificationChannel(channel);

      const AndroidInitializationSettings androidInitSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const DarwinInitializationSettings iosInitSettings =
          DarwinInitializationSettings();

      await _notificationsPlugin.initialize(
        const InitializationSettings(
          android: androidInitSettings,
          iOS: iosInitSettings,
        ),
      );

      debugPrint("✅ Notifications Initialized & Channel Created");
    } catch (e) {
      debugPrint("❌ Notification Init Error: $e");
    }
  }

  Future<void> _triggerStatusNotification(String status) async {
    if (kIsWeb) return;

    String title = "";
    String body = "";
    String checkStatus = status.toLowerCase();

    if (checkStatus == 'baking' || checkStatus == 'preparing') {
      title = "🧑‍🍳 Order Preparing!";
      body = "Great news! Your treats are now being freshly prepared.";
    } else if (checkStatus == 'out for delivery' ||
        checkStatus.contains('way')) {
      title = "🛵 Out for Delivery!";
      body = "Hang tight! Your order is on the way to your address.";
    } else if (checkStatus == 'delivered') {
      title = "🥳 Order Delivered!";
      body = "Your order has arrived safely. Enjoy your treats! 🎉";
    } else if (checkStatus == 'cancelled') {
      title = "❌ Order Cancelled";
      body = "Your order has been cancelled.";
    } else {
      return;
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'bhs_orders_high_priority_v5',
            'Order Status Updates',
            channelDescription: 'Real-time updates for your cake orders',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFFFF2E74),
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.status,
            visibility: NotificationVisibility.public,
          );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          presentBadge: true,
        ),
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecond,
        title,
        body,
        platformDetails,
      );
      debugPrint("✅ Notification call executed for: $status");
    } catch (e) {
      debugPrint("❌ Notification Error: $e");
    }
  }

  String _getFlavourText(dynamic flavours) {
    if (flavours == null ||
        flavours.toString().trim().isEmpty ||
        flavours.toString() == '{}')
      return "";
    String raw = flavours.toString().trim();
    if (!raw.startsWith('{')) return raw;
    try {
      if (flavours is String) {
        final Map<String, dynamic> map = jsonDecode(flavours);
        return map.isEmpty ? "" : map.keys.join(", ");
      }
      if (flavours is Map)
        return flavours.isEmpty ? "" : flavours.keys.join(", ");
    } catch (e) {
      return raw.replaceAll(RegExp(r'[{}"\]\[]'), '').trim();
    }
    return "";
  }

  int _getCurrentStep(String status) {
    status = status.toLowerCase();
    if (status.contains('paid') || status.contains('pending')) return 0;
    if (status.contains('baking') || status.contains('preparing')) return 1;
    if (status.contains('out') || status.contains('way')) return 2;
    if (status.contains('delivered') || status.contains('completed')) return 3;
    return 0;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _accentPink));
          }

          if (!snapshot.hasData || !snapshot.data!.exists)
            return _buildErrorState();

          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          final items = orderData['items'] as List<dynamic>? ?? [];
          final status = orderData['status'] ?? "Pending";
          final String address = orderData['userAddress'] ?? "Pickup at Store";

          final String receiverName =
              orderData['receiverName']?.toString().trim() ??
              'Same as Customer';
          final String receiverPhone =
              orderData['receiverPhone']?.toString().trim() ??
              'Same as Customer';
          final String deliverySchedule =
              orderData['deliverySchedule']?.toString() ?? 'ASAP';
          final bool isASAP = deliverySchedule.toUpperCase() == 'ASAP';

          Timestamp? createdAt = orderData['createdAt'] as Timestamp?;
          bool isWithin15Mins = false;
          if (createdAt != null) {
            isWithin15Mins =
                DateTime.now().difference(createdAt.toDate()).inMinutes < 15;
          }

          bool isCancelled = status.toString().toLowerCase() == 'cancelled';
          int currentStep = _getCurrentStep(status);
          bool isEditable =
              (currentStep == 0) && !isCancelled && isWithin15Mins;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isInitialLoad) {
              _lastStatus = status;
              _isInitialLoad = false;
              debugPrint("🚀 Initial Status Loaded: $status");
            } else if (_lastStatus != status && status.isNotEmpty) {
              debugPrint("🔄 Status Changed from $_lastStatus to $status");
              _triggerStatusNotification(status);
              _lastStatus = status;
            }
          });

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(
                status,
                isCancelled,
                orderData['orderId'] ?? widget.orderId,
                createdAt,
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isCancelled) _buildGlassTimeline(currentStep),
                      if (isCancelled) _buildCancelledBanner(),

                      const SizedBox(height: 16),

                      if (isEditable)
                        _buildEditableBanner()
                      else if (!isCancelled && currentStep == 0)
                        _buildLockedBanner(),

                      const SizedBox(height: 24),
                      Text(
                        "ORDER SUMMARY",
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[500],
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ListView.separated(
                              padding: const EdgeInsets.all(16),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (c, i) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: Colors.grey.shade100,
                                ),
                              ),
                              itemBuilder: (context, index) {
                                return _buildSeamlessItemRow(
                                  items[index],
                                  index,
                                  isEditable,
                                  items,
                                );
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _accentPink.withOpacity(0.04),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Total Paid",
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "₹${orderData['totalPrice'] ?? '0'}",
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: _accentPink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        "DELIVERY DETAILS",
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[500],
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.location_on_rounded,
                              Colors.blueAccent,
                              "Delivery Address",
                              address,
                              isEditable: isEditable,
                              onTapEdit: () => _editAddress(address),
                            ),
                            Divider(
                              height: 1,
                              color: Colors.grey.shade100,
                              indent: 50,
                            ),
                            _buildInfoRow(
                              Icons.person_rounded,
                              Colors.orangeAccent,
                              "Receiver",
                              receiverPhone.toLowerCase() == 'same as customer'
                                  ? receiverName
                                  : "$receiverName\n$receiverPhone",
                              isEditable: isEditable,
                              onTapEdit: () => _editReceiverDetails(
                                receiverName,
                                receiverPhone,
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: Colors.grey.shade100,
                              indent: 50,
                            ),
                            _buildInfoRow(
                              isASAP
                                  ? Icons.bolt_rounded
                                  : Icons.schedule_rounded,
                              Colors.purpleAccent,
                              "Schedule",
                              isASAP ? "ASAP Delivery" : deliverySchedule,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      _buildHelpSection(),

                      if (isEditable)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Center(child: _buildCancelButton()),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(
    String status,
    bool isCancelled,
    String displayId,
    Timestamp? time,
  ) {
    Color statusColor = isCancelled
        ? Colors.red
        : (status == 'Delivered' ? _successGreen : _accentPink);

    return SliverAppBar(
      expandedHeight: 120,
      backgroundColor: _premiumBlack,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 14,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: Text(
          isCancelled ? "ORDER CANCELLED" : status.toUpperCase(),
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        background: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 25),
            Text(
              "Order #${displayId.length > 8 ? displayId.substring(0, 8) : displayId}",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(time),
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassTimeline(int currentStep) {
    final steps = [
      {'label': 'Placed', 'icon': Icons.receipt_long},
      {'label': 'Baking', 'icon': Icons.outdoor_grill_rounded},
      {'label': 'On Way', 'icon': Icons.delivery_dining},
      {'label': 'Delivered', 'icon': Icons.check_circle_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          bool isActive = index <= currentStep;
          return Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isActive ? _accentPink : Colors.grey[100],
                    shape: BoxShape.circle,
                    boxShadow: (isActive && index == currentStep)
                        ? [
                            BoxShadow(
                              color: _accentPink.withOpacity(0.3),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    steps[index]['icon'] as IconData,
                    color: isActive ? Colors.white : Colors.grey[400],
                    size: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  steps[index]['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? _premiumBlack : Colors.grey[400],
                  ),
                ),
                if (index < steps.length - 1)
                  Transform.translate(
                    offset: const Offset(30, -26),
                    child: Container(
                      height: 2,
                      width: 25,
                      color: index < currentStep
                          ? _accentPink
                          : Colors.grey[200],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSeamlessItemRow(
    Map<String, dynamic> item,
    int index,
    bool isEditable,
    List allItems,
  ) {
    String flavor = _getFlavourText(
      item['flavour'] ?? item['flavor'] ?? item['flavours'],
    );
    String shape = (item['shape'] ?? "").toString().trim();
    String weight = (item['weight'] ?? "").toString().trim();
    String writing = (item['cakeWriting'] ?? "").toString().trim();
    String quantity = (item['quantity'] ?? 1).toString().trim();
    String category = (item['category'] ?? "").toString().toLowerCase().trim();
    String itemName = (item['name'] ?? "Delicious Item").toString().trim();

    bool isCupcake =
        category == 'cupcake' ||
        category == 'addon' ||
        category == 'addons' ||
        category == 'popsicle' ||
        itemName.toLowerCase().contains('cupcake');
    bool hasTags =
        (weight.isNotEmpty && weight != "N/A") ||
        (!isCupcake &&
            shape.isNotEmpty &&
            shape != 'Standard' &&
            shape != 'N/A') ||
        (!isCupcake && flavor.isNotEmpty && flavor != 'N/A');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 55,
            width: 55,
            color: _bgGrey,
            child: _buildImage(item['image']?.toString()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      itemName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "₹${item['price']}",
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _premiumBlack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "Qty: $quantity",
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),

              if (hasTags) const SizedBox(height: 6),
              if (hasTags)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (weight.isNotEmpty && weight != "N/A")
                      _buildTag(
                        weight,
                        isCupcake ? Icons.numbers_rounded : Icons.scale_rounded,
                      ),
                    if (!isCupcake &&
                        shape.isNotEmpty &&
                        shape != 'Standard' &&
                        shape != 'N/A')
                      _buildTag(shape, Icons.interests_rounded),
                    if (!isCupcake && flavor.isNotEmpty && flavor != 'N/A')
                      _buildTag(
                        flavor,
                        Icons.local_dining_rounded,
                        isHighlight: true,
                      ),
                  ],
                ),

              if (!isCupcake) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 12,
                        color: Color(0xFFFF2E74),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        writing.isEmpty ||
                                writing.toLowerCase() == "no message" ||
                                writing.toLowerCase() == "no writing"
                            ? "No message"
                            : "\"$writing\"",
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    if (isEditable)
                      GestureDetector(
                        onTap: () => _editCakeWriting(index, writing, allItems),
                        child: Text(
                          "EDIT",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _accentPink,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text, IconData icon, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlight
            ? _accentPink.withOpacity(0.08)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 8,
            color: isHighlight ? _accentPink : Colors.grey[600],
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isHighlight ? Colors.pink : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    Color iconColor,
    String title,
    String value, {
    bool isEditable = false,
    VoidCallback? onTapEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.trim(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _premiumBlack,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (isEditable)
            GestureDetector(
              onTap: onTapEdit,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(Icons.edit, size: 14, color: Colors.grey[400]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
    return GestureDetector(
      onTap: () => _launchURL("tel:+919037084037"),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F4FD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.support_agent_rounded,
              color: Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Need Help?",
                    style: GoogleFonts.montserrat(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    "Tap to call support",
                    style: GoogleFonts.inter(
                      color: Colors.blue.shade700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.blue,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: Colors.blue.shade400, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You can edit details for a few minutes.",
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Modifications locked. Order is processing.",
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel, color: Colors.red.shade400, size: 14),
          const SizedBox(width: 6),
          Text(
            "This order was cancelled.",
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: _showCancelDialog,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        "Cancel Order",
        style: GoogleFonts.inter(
          fontSize: 11,
          color: Colors.grey.shade500,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 15),
            Text(
              "Order details not available",
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? imageString) {
    try {
      if (imageString == null || imageString.trim().isEmpty)
        return _premiumPlaceholder();
      if (imageString.startsWith('http'))
        return Image.network(
          imageString,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _premiumPlaceholder(),
        );
      if (imageString.startsWith('assets/'))
        return Image.asset(
          imageString,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _premiumPlaceholder(),
        );

      String cleanBase64 = imageString;
      if (cleanBase64.contains(',')) cleanBase64 = cleanBase64.split(',').last;
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
      return Image.memory(
        base64Decode(cleanBase64),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _premiumPlaceholder(),
      );
    } catch (e) {
      return _premiumPlaceholder();
    }
  }

  Widget _premiumPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentPink.withOpacity(0.2), _accentPink.withOpacity(0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.cake_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Cancel Order?",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          "This action cannot be undone.",
          style: GoogleFonts.inter(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("No", style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _performCancellation();
            },
            child: Text(
              "Yes, Cancel",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancellation() async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({'status': 'Cancelled'});
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('orders')
          .child(widget.orderId)
          .update({'status': 'Cancelled'});
    }
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order Cancelled"),
          backgroundColor: Colors.red,
        ),
      );
  }

  void _editAddress(String currentAddress) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "CHANGE LOCATION",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            _buildLocationOptionTile(
              icon: Icons.my_location_rounded,
              title: "Current Location",
              subtitle: "Using high-accuracy GPS",
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _determinePosition();
              },
            ),
            _buildLocationOptionTile(
              icon: Icons.map_outlined,
              title: "Select on Map",
              subtitle: "Pin your exact doorstep",
              color: Colors.orange,
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LocationPage()),
                );
                if (result != null && result is Map)
                  _showAddressEntryForm(
                    result['address'],
                    result['lat'],
                    result['lng'],
                  );
              },
            ),
            const Divider(height: 30, indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "RECENTLY USED",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('addresses')
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;
                  if (docs.isEmpty)
                    return Center(
                      child: Text(
                        "No saved addresses",
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    );
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                        title: Text(
                          data['fullAddress'] ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 14),
                        onTap: () {
                          Navigator.pop(context);
                          _updateDatabaseAddress(data['fullAddress']);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _determinePosition() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF2E74)),
      ),
    );
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> p = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      String area = p.isNotEmpty
          ? "${p[0].subLocality}, ${p[0].locality}"
          : "Unknown Area";
      Navigator.pop(context);
      _showAddressEntryForm(area, pos.latitude, pos.longitude);
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar("Could not fetch location", Colors.red);
    }
  }

  void _showAddressEntryForm(String area, double lat, double lng) {
    final houseCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "COMPLETE ADDRESS",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: houseCtrl,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.home_outlined,
                    color: _accentPink,
                    size: 18,
                  ),
                  hintText: "House / Flat No / Landmark",
                  hintStyle: GoogleFonts.inter(fontSize: 12),
                  filled: true,
                  fillColor: _bgGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Area: $area",
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _premiumBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (houseCtrl.text.isEmpty) return;
                    _updateDatabaseAddress("${houseCtrl.text}, $area");
                    Navigator.pop(context);
                  },
                  child: Text(
                    "UPDATE ADDRESS",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 12)),
        backgroundColor: color,
      ),
    );
  }

  void _editReceiverDetails(String currentName, String currentPhone) {
    TextEditingController nameCtrl = TextEditingController(
      text: currentName.toLowerCase() == 'same as customer' ? '' : currentName,
    );
    TextEditingController phoneCtrl = TextEditingController(
      text: currentPhone.toLowerCase() == 'same as customer'
          ? ''
          : currentPhone,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Update Receiver",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.inter(fontSize: 12),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                filled: true,
                fillColor: _bgGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                hintText: "Receiver Name",
                prefixIcon: const Icon(Icons.person_outline, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.inter(fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: _bgGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                hintText: "Receiver Phone",
                prefixIcon: const Icon(Icons.phone, size: 18),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _premiumBlack,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(widget.orderId)
                        .update({
                          'receiverName': nameCtrl.text.trim(),
                          'receiverPhone': phoneCtrl.text.trim(),
                        });
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null)
                      await FirebaseDatabase.instance
                          .ref()
                          .child('users')
                          .child(user.uid)
                          .child('orders')
                          .child(widget.orderId)
                          .update({
                            'receiverName': nameCtrl.text.trim(),
                            'receiverPhone': phoneCtrl.text.trim(),
                          });
                    if (mounted) {
                      Navigator.pop(context);
                      _showSnackBar("Receiver details updated!", Colors.green);
                    }
                  } else {
                    _showSnackBar("Please fill in both fields", Colors.red);
                  }
                },
                child: Text(
                  "Save Details",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editCakeWriting(int index, String currentText, List<dynamic> allItems) {
    TextEditingController controller = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Cake Message",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLength: 30,
          style: GoogleFonts.inter(fontSize: 12),
          decoration: const InputDecoration(
            hintText: "Happy Birthday...",
            counterText: "",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.inter(fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentPink,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              allItems[index]['cakeWriting'] = controller.text.trim();
              await FirebaseFirestore.instance
                  .collection('orders')
                  .doc(widget.orderId)
                  .update({'items': allItems});
              final user = FirebaseAuth.instance.currentUser;
              if (user != null)
                await FirebaseDatabase.instance
                    .ref()
                    .child('users')
                    .child(user.uid)
                    .child('orders')
                    .child(widget.orderId)
                    .child('items')
                    .child(index.toString())
                    .update({'cakeWriting': controller.text.trim()});
              if (mounted) Navigator.pop(context);
            },
            child: Text(
              "Save",
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    try {
      await launchUrl(
        Uri.parse(urlString),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _updateDatabaseAddress(String newAddress) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'userAddress': newAddress.trim()});
      final user = FirebaseAuth.instance.currentUser;
      if (user != null)
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(user.uid)
            .child('orders')
            .child(widget.orderId)
            .update({'userAddress': newAddress.trim()});
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("Address updated successfully!", Colors.green);
      }
    } catch (_) {}
  }
}
