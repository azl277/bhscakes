import "dart:io";

void main() {
  final files = [
    "lib/cakepage.dart",
    "lib/cupcakepage.dart",
    "lib/giftpage.dart",
    "lib/customisepage.dart",
    "lib/addons.dart",
    "lib/addonspage.dart",
    "lib/cartpage1.dart",
    "lib/cartpage2.dart",
    "lib/orderhistory.dart"
  ];

  for (var path in files) {
    var file = File(path);
    if (!file.existsSync()) continue;
    var content = file.readAsStringSync();

    content = content.replaceAll("currentUser!.phoneNumber", "currentUser?.phoneNumber");
    content = content.replaceAll("currentUser!.displayName", "currentUser?.displayName");
    content = content.replaceAll("currentUser!", "currentUser");
    content = content.replaceAll("user!", "user");
    content = content.replaceAll("snapshot.data!", "snapshot.data");
    
    file.writeAsStringSync(content);
    print("Fixed further '\$' on \");
  }
}
