// ignore_for_file: avoid_print

class Base {
  final String id;
  Base({required this.id});
  
  Map<String, dynamic> toJson() => {'id': id};
}

class Sub extends Base {
  Sub() : super(id: 'base_id');
  
  @override
  String get id => 'sub_id';
}

void main() {
  final s = Sub();
  print(s.toJson());
}
