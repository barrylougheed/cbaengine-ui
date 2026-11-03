import 'package:equatable/equatable.dart';

import 'lea.dart';

/// One area a searched-for place is in: POST /places/search.
class PlaceMatch extends Equatable {
  const PlaceMatch({required this.place, required this.councilId, required this.lea});

  /// The place as named (Swords, Athlone West), which may be part of the area.
  final String place;
  final String councilId;
  final Lea lea;

  factory PlaceMatch.fromJson(Map<String, dynamic> json) {
    return PlaceMatch(
      place: json['place'] as String,
      councilId: json['council_id'] as String,
      lea: Lea.fromJson(json['lea'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [place, councilId, lea];
}

/// The areas that match, best first, and how many matched in all.
class PlaceSearchResults extends Equatable {
  const PlaceSearchResults({required this.results, required this.total});

  final List<PlaceMatch> results;
  final int total;

  /// More matched than are shown: the resident should type more of the name.
  bool get isCutShort => total > results.length;

  factory PlaceSearchResults.fromJson(Map<String, dynamic> json) {
    return PlaceSearchResults(
      results: (json['results'] as List<dynamic>).map((r) => PlaceMatch.fromJson(r as Map<String, dynamic>)).toList(),
      total: (json['total'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [results, total];
}
