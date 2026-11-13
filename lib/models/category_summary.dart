import 'package:equatable/equatable.dart';

/// One category of GET /topics: a group of issues (Housing, Healthcare...) a
/// resident picks first, before the specific issues in it. The server sends only
/// categories that have at least one issue ready, in the owner's order.
class CategorySummary extends Equatable {
  const CategorySummary({required this.id, required this.title});

  final String id;
  final String title;

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(id: json['id'] as String, title: json['title'] as String);
  }

  @override
  List<Object?> get props => [id, title];
}
