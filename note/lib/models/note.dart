import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final DateTime? reminderDateTime;
  final int? color;

  Note({
    String? id,
    required this.userId,
    required this.title,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
    this.reminderDateTime,
    this.color,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    DateTime? reminderDateTime,
    int? color,
    bool removeReminder = false,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isPinned: isPinned ?? this.isPinned,
      reminderDateTime:
          removeReminder ? null : (reminderDateTime ?? this.reminderDateTime),
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isPinned': isPinned,
      'reminderDateTime': reminderDateTime,
      'color': color,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      content: map['content'],
      createdAt:
          map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt'].toString()),
      updatedAt:
          map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(map['updatedAt'].toString()),
      isPinned: map['isPinned'] ?? false,
      reminderDateTime:
          map['reminderDateTime'] != null
              ? (map['reminderDateTime'] is Timestamp
                  ? (map['reminderDateTime'] as Timestamp).toDate()
                  : DateTime.parse(map['reminderDateTime'].toString()))
              : null,
      color: map['color'],
    );
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isPinned: json['isPinned'] ?? false,
      reminderDateTime:
          json['reminderDateTime'] != null
              ? DateTime.parse(json['reminderDateTime'])
              : null,
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'reminderDateTime': reminderDateTime?.toIso8601String(),
      'color': color,
    };
  }

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Note(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      createdAt:
          data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      updatedAt:
          data['updatedAt'] is Timestamp
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.now(),
      isPinned: data['isPinned'] ?? false,
      reminderDateTime:
          data['reminderDateTime'] != null
              ? (data['reminderDateTime'] is Timestamp
                  ? (data['reminderDateTime'] as Timestamp).toDate()
                  : null)
              : null,
      color: data['color'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isPinned': isPinned,
      'reminderDateTime':
          reminderDateTime != null
              ? Timestamp.fromDate(reminderDateTime!)
              : null,
      'color': color,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
