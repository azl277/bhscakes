import "dart:io";

void main() {
  final files = Directory("lib").listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  for (var file in files) {
    var content = file.readAsStringSync();
    var originalContent = content;

    content = content.replaceAll("snapshot.data?.docs.isEmpty == true", "(snapshot.data?.docs.isEmpty ?? true)");
    
    var regexStr = RegExp(r"(\w+)\[\'([a-zA-Z]+)\'\] \?\? \"\"\.([a-zA-Z]+)");
    content = content.replaceAllMapped(regexStr, (m) {
      return "(${m.group(1)}['${m.group(2)}'] ?? \"\").${m.group(3)}";
    });

    var regexStrWidget = RegExp(r"widget\.(\w+)\[\'([a-zA-Z]+)\'\] \?\? \"\"\.([a-zA-Z]+)");
    content = content.replaceAllMapped(regexStrWidget, (m) {
      return "(widget.${m.group(1)}['${m.group(2)}'] ?? \"\").${m.group(3)}";
    });

    content = content.replaceAll("item['desc'] ?? \"\".isNotEmpty", "(item['desc'] ?? \"\").isNotEmpty");

    content = content.replaceAll("snapshot.data?.docs.map", "(snapshot.data?.docs ?? []).map");
    content = content.replaceAll("snapshot.data?.docs.length", "(snapshot.data?.docs ?? []).length");
    content = content.replaceAll("snapshot.data?.docs[", "(snapshot.data?.docs ?? [])[");

    if (file.path.contains("secondpage.dart")) {
      content = content.replaceAll("doc.id", "doc?.id ?? ''");
      content = content.replaceAll("doc?.id ?? ''?.id ?? ''", "doc?.id ?? ''");
      content = content.replaceAll("(doc?.id ?? '') ?? ''", "doc?.id ?? ''");
    }

    if (content != originalContent) {
      file.writeAsStringSync(content);
      print("Fixed ${file.path}");
    }
  }
}
