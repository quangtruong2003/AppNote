import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d, yyyy').format(note.updatedAt);

    // Generate a pastel color based on the note title
    final color = _generatePastelColor(
      note.title.isNotEmpty ? note.title[0] : 'A',
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            note.isPinned
                ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
                : BorderSide.none,
      ),
      elevation: note.isPinned ? 4 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      note.title.isNotEmpty ? note.title[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (note.isPinned) const Icon(Icons.push_pin, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (note.reminderDateTime != null)
                    Icon(
                      Icons.notifications_active,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  const SizedBox(width: 8),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _generatePastelColor(String seed) {
    // Generate a consistent color based on the first letter of the title
    final colorSeed = seed.codeUnitAt(0) % 9;

    final List<Color> pastelColors = [
      const Color(0xFFFFC3A0), // Peach
      const Color(0xFFFFAFCC), // Pink
      const Color(0xFFBDE0FE), // Light Blue
      const Color(0xFFA0C4FF), // Blue
      const Color(0xFFCDB4DB), // Lavender
      const Color(0xFFB9FBC0), // Mint
      const Color(0xFFFDFFB6), // Yellow
      const Color(0xFFCFBCDF), // Purple
      const Color(0xFFFFD6A5), // Orange
    ];

    return pastelColors[colorSeed];
  }
}
