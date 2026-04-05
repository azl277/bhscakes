import 'dart:io';

void main() {
  final filesToFix = {
    "lib/cakepage.dart": _fixBadSyntaxAndMore,
    "lib/giftpage.dart": _fixBadSyntaxAndMore,
    "lib/cartpage1.dart": _fixBadSyntaxAndMore,
    "lib/cupcakepage.dart": _fixBadSyntaxAndMore,
    "lib/orderhistory.dart": _fixBadSyntaxAndMore,
    "lib/orderpage.dart": _fixBooleanFix,
    "lib/addonspage.dart": _fixPropertyAccess,
  };

  for (var entry in filesToFix.entries) {
    var path = entry.key;
    var fixFunction = entry.value;

    var file = File(path);
    if (!file.existsSync()) continue;
    var content = file.readAsStringSync();
    var newContent = fixFunction(content, path);

    if (content != newContent) {
      file.writeAsStringSync(newContent);
      print("Applied fixes to \$path");
    }
  }
}

String _fixBadSyntaxAndMore(String content, String path) {
  content = content.replaceAll("(snapshot.data?.(docs?.isEmpty ?? true) ?? true)", "(snapshot.data?.docs?.isEmpty ?? true)");

  content = content.replaceAll("sortedDocs.map((doc)", "(sortedDocs ?? []).map((doc)");

  if (path.contains("cartpage1.dart")) {
  }

  if (path.contains("orderhistory.dart")) {
    content = content.replaceAll("_buildPremiumOrderCard(orderData, orderId)", "_buildPremiumOrderCard(orderData, orderId ?? '')");
  }

  return content;
}

String _fixBooleanFix(String content, String path) {
  content = content.replaceAll("!snapshot.data?.exists == true", "(snapshot.data?.exists != true)");
  return content;
}

String _fixPropertyAccess(String content, String path) {
  content = content.replaceAll("doc.data()", "doc?.data()");
  content = content.replaceAll("doc.id", "(doc?.id ?? '')");
  content = content.replaceAll("((doc?.id ?? '') ?? '')", "(doc?.id ?? '')");
  content = content.replaceAll("(doc?.id ?? '') ?? ''", "(doc?.id ?? '')");
  return content;
}
