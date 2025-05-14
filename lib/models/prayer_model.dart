class PrayerModel {
  final String id;
  final String date;
  final String prayerType;
  final String content;

  PrayerModel({
    required this.id,
    required this.date,
    required this.prayerType,
    required this.content,
  });

  factory PrayerModel.fromJson(Map<String, dynamic> json) => PrayerModel(
    id: json['id'],
    date: json['date'],
    prayerType: json['prayerType'],
    content: json['content'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'prayerType': prayerType,
    'content': content,
  };

  static List<PrayerModel> listFromJson(List<dynamic> jsonList) {
    return jsonList.map((e) => PrayerModel.fromJson(e)).toList();
  }

  static List<Map<String, dynamic>> listToJson(List<PrayerModel> list) {
    return list.map((e) => e.toJson()).toList();
  }
}
