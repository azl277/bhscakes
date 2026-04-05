import 'dart:io';

void main() {
  final dir = Directory('lib');
  for (var file in dir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    var content = file.readAsStringSync();
    var orig = content;

    content = content.replaceAll("snapshot.data?.docs.isEmpty)", "(snapshot.data?.docs.isEmpty ?? true))");
    content = content.replaceAll("snapshot.data?.docs.isEmpty {", "(snapshot.data?.docs.isEmpty ?? true) {");
    content = content.replaceAll("snapshot.data?.docs.isEmpty == true", "(snapshot.data?.docs.isEmpty ?? true)");
    content = content.replaceAll("!snapshot.hasData || snapshot.data?.docs.isEmpty", "!snapshot.hasData || (snapshot.data?.docs.isEmpty ?? true)");

    content = content.replaceAll("snapshot.data!.docs.isEmpty", "(snapshot.data?.docs.isEmpty ?? true)");

    content = content.replaceAll("snapshot.data?.docs.length", "(snapshot.data?.docs.length ?? 0)");
    
    content = content.replaceAll("snapshot.data?.docs.map", "(snapshot.data?.docs ?? []).map");

    if (file.path.contains("secondpage.dart")) {
      content = content.replaceAll("doc.id", "doc?.id ?? ''");
      content = content.replaceAll("doc?.id ?? ''?.id ?? ''", "doc?.id ?? ''");
      content = content.replaceAll("(doc?.id ?? '') ?? ''", "doc?.id ?? ''");
    }

    content = content.replaceAll("item['desc'] ?? \"\".isNotEmpty", "(item['desc'] ?? \"\").isNotEmpty");
    content = content.replaceAll("item['desc'] ?? \"\".isNotEmpty)", "(item['desc'] ?? \"\").isNotEmpty)");

    if (content != orig) {
      file.writeAsStringSync(content);
      print("Fixed \${file.path}");
    }
  }
}
