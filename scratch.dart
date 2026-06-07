void main() {
  Map<String, dynamic> dynMap = {'a': 1};
  try {
    processMap(dynMap);
    print("Success");
  } catch (e) {
    print("Failed: $e");
  }
}

void processMap(Map<String, Object?> map) {
  print(map);
}
