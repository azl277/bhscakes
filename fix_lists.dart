import 'dart:io';

void main() {
  final files = [
    "lib/cakepage.dart",
    "lib/orderpage.dart",
    "lib/giftpage.dart",
    "lib/cartpage1.dart",
    "lib/cupcakepage.dart",
    "lib/addonspage.dart",
    "lib/orderhistory.dart"
  ];

  for (String path in files) {
    File file = File(path);
    if (!file.existsSync()) continue;
    print("Modifying $path...");
    String content = file.readAsStringSync();
    String orig = content;

    List<String> listNames = ['sortedDocs', 'docs', 'addons', 'orders'];
    for (String listName in listNames) {
      content = content.replaceAll("...$listName.map(", "...($listName ?? []).map(");
      
      content = content.replaceAll("$listName.sort(", "$listName?.sort(");
      
      content = content.replaceAll("$listName.length", "($listName?.length ?? 0)");
      content = content.replaceAll("(($listName?.length ?? 0) ?? 0)", "($listName?.length ?? 0)");
      
      content = content.replaceAll("$listName.isEmpty", "($listName?.isEmpty ?? true)");
      content = content.replaceAll("(($listName?.isEmpty ?? true) ?? true)", "($listName?.isEmpty ?? true)");
      content = content.replaceAll("(($listName?.isEmpty ?? true) == true)", "(($listName?.isEmpty ?? true) == true)");

      content = content.replaceAll("$listName[", "$listName?[");
      content = content.replaceAll("$listName??[", "$listName?["); 
    }

    if (content != orig) {
      file.writeAsStringSync(content);
      print("-> Fixed nullability mappings in $path");
    }
  }
}
