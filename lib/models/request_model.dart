class RequestModel {
  final String requestId;
  final String requesterId;
  final String type;
  final String title;
  final String description;
  final double? amount;
  final double latitude;
  final double longitude;
  final int radiusKm;
  final String status;

  const RequestModel({
    required this.requestId,
    required this.requesterId,
    required this.type,
    required this.title,
    required this.description,
    this.amount,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.status,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      requestId: json['request_id'] as String,
      requesterId: json['requester_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      amount: json['amount'] == null
          ? null
          : (json['amount'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusKm: (json['radius_km'] as num).toInt(),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'requester_id': requesterId,
      'type': type,
      'title': title,
      'description': description,
      'amount': amount,
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
      'status': status,
    };
  }

  bool get isPaid =>
      type == 'Paid Rent' || type == 'Paid Task';

  bool get isFree =>
      type == 'Free Borrow' || type == 'Free Favour';
}
