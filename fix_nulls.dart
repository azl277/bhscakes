import "dart:io";

void main() {
  final files = [
    "lib/orderpage.dart",
    "lib/paymet.dart"
  ];

  for (var path in files) {
    var file = File(path);
    if (!file.existsSync()) continue;
    var content = file.readAsStringSync();

    final regex = RegExp(r"(\w+)\[\'([a-zA-Z]+)\'\]!");
    content = content.replaceAllMapped(regex, (match) {
      final mapName = match.group(1);
      final keyName = match.group(2);
      return "$mapName['$keyName'] ?? \"\"";
    });
    
    content = content.replaceAll("snapshot.data!.docs", "snapshot.data?.docs");
    content = content.replaceAll("snapshot.data!.data()", "snapshot.data?.data()");
    content = content.replaceAll("snapshot.data!.exists", "snapshot.data?.exists == true");
    content = content.replaceAll("rtdbSnapshot.data!.snapshot.exists", "rtdbSnapshot.data?.snapshot.exists == true");
    content = content.replaceAll("currentUser!.uid", "currentUser?.uid ?? \"\"");
    
    file.writeAsStringSync(content);
    print("Fixed $path");
  }
}
