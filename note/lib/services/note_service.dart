import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/note.dart';
import '../services/notification_service.dart';

class NoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _notesCollection = 'notes';
  final String _usersCollection = 'users';
  final NotificationService _notificationService = NotificationService();

  // Create a new note
  Future<Note> addNote(Note note) async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        // Save locally if offline
        await _saveNoteLocally(note);
        return note;
      } else {
        // Save to Firestore if online
        final docRef = await _firestore
            .collection(_notesCollection)
            .add(note.toFirestore());

        // Update the note with the generated ID
        final updatedNote = note.copyWith(id: docRef.id);
        await docRef.update({'id': docRef.id});

        // Update user's note count
        await _updateUserNoteCount(note.userId);

        // Schedule notification if reminder is set
        if (updatedNote.reminderDateTime != null) {
          await _scheduleReminderNotification(updatedNote);
        }

        return updatedNote;
      }
    } catch (e) {
      // If there's an error, try to save locally
      await _saveNoteLocally(note);
      throw Exception('Failed to create note: $e');
    }
  }

  // Get all notes for a user
  Future<List<Note>> getNotes(String userId) async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        // Return locally saved notes if offline
        return _getLocalNotes(userId);
      } else {
        // Get from Firestore if online
        final snapshot =
            await _firestore
                .collection(_notesCollection)
                .where('userId', isEqualTo: userId)
                .get();

        final notes =
            snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();

        // Save all notes locally for offline access
        await _saveNotesLocally(notes);

        return notes;
      }
    } catch (e) {
      // If there's an error, try to get locally saved notes
      final localNotes = await _getLocalNotes(userId);
      if (localNotes.isNotEmpty) {
        return localNotes;
      }
      throw Exception('Failed to fetch notes: $e');
    }
  }

  // Update an existing note
  Future<Note> updateNote(Note note) async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        // Update locally if offline
        await _updateNoteLocally(note);
        return note;
      } else {
        // Update in Firestore if online
        await _firestore
            .collection(_notesCollection)
            .doc(note.id)
            .update(note.toFirestore());

        // Also update locally
        await _updateNoteLocally(note);

        // Handle reminder notification
        if (note.reminderDateTime != null) {
          await _scheduleReminderNotification(note);
        } else {
          await _cancelReminderNotification(note.id);
        }

        return note;
      }
    } catch (e) {
      // If there's an error, try to update locally
      await _updateNoteLocally(note);
      throw Exception('Failed to update note: $e');
    }
  }

  // Delete a note
  Future<void> deleteNote(String noteId) async {
    try {
      // Get the note first to know the user ID
      final noteDoc =
          await _firestore.collection(_notesCollection).doc(noteId).get();
      final userId = noteDoc.data()?['userId'] as String?;

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        // Mark as deleted locally if offline
        await _markNoteAsDeletedLocally(noteId);
      } else {
        // Delete from Firestore if online
        await _firestore.collection(_notesCollection).doc(noteId).delete();

        // Also mark as deleted locally
        await _markNoteAsDeletedLocally(noteId);

        // Update user's note count if we have the userId
        if (userId != null) {
          await _updateUserNoteCount(userId, decrement: true);
        }

        // Cancel any scheduled notification
        await _cancelReminderNotification(noteId);
      }
    } catch (e) {
      // If there's an error, try to mark as deleted locally
      await _markNoteAsDeletedLocally(noteId);
      throw Exception('Failed to delete note: $e');
    }
  }

  // Schedule a reminder notification
  Future<void> _scheduleReminderNotification(Note note) async {
    if (note.reminderDateTime == null) return;

    // Cancel any existing notification for this note
    await _cancelReminderNotification(note.id);

    // Schedule new notification
    await _notificationService.scheduleNotification(
      id: note.id.hashCode,
      title: 'Reminder: ${note.title}',
      body:
          note.content.length > 100
              ? '${note.content.substring(0, 97)}...'
              : note.content,
      scheduledDate: note.reminderDateTime!,
      payload: note.id,
    );
  }

  // Cancel a reminder notification
  Future<void> _cancelReminderNotification(String noteId) async {
    await _notificationService.cancelNotification(noteId.hashCode);
  }

  // Update user's note count
  Future<void> _updateUserNoteCount(
    String userId, {
    bool decrement = false,
  }) async {
    final userRef = _firestore.collection(_usersCollection).doc(userId);

    // Use transactions to safely update the count
    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);

      if (userDoc.exists) {
        int currentCount = userDoc.data()?['notesCount'] ?? 0;
        int newCount =
            decrement
                ? (currentCount > 0 ? currentCount - 1 : 0)
                : currentCount + 1;

        transaction.update(userRef, {'notesCount': newCount});
      }
    });
  }

  // Save a note locally
  Future<void> _saveNoteLocally(Note note) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get existing notes or initialize empty list
    List<String> notesJson = prefs.getStringList('local_notes') ?? [];

    // Add the new note
    notesJson.add(jsonEncode(note.toJson()));

    // Save back to SharedPreferences
    await prefs.setStringList('local_notes', notesJson);

    // Also save to pending uploads for syncing later
    await _addToPendingUploads(note);
  }

  // Get locally saved notes for a user
  Future<List<Note>> _getLocalNotes(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get all saved notes
    List<String> notesJson = prefs.getStringList('local_notes') ?? [];

    // Get deleted note IDs
    Set<String> deletedNoteIds = Set<String>.from(
      prefs.getStringList('deleted_notes') ?? [],
    );

    // Parse and filter by user ID and not deleted
    List<Note> userNotes = [];
    for (String noteJson in notesJson) {
      try {
        final Map<String, dynamic> noteMap = jsonDecode(noteJson);
        final Note note = Note.fromJson(noteMap);

        if (note.userId == userId && !deletedNoteIds.contains(note.id)) {
          userNotes.add(note);
        }
      } catch (e) {
        // Skip malformed notes
        continue;
      }
    }

    return userNotes;
  }

  // Save multiple notes locally
  Future<void> _saveNotesLocally(List<Note> notes) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Convert all notes to JSON strings
    List<String> notesJson =
        notes.map((note) => jsonEncode(note.toJson())).toList();

    // Save to SharedPreferences
    await prefs.setStringList('local_notes', notesJson);
  }

  // Update a note locally
  Future<void> _updateNoteLocally(Note note) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get existing notes
    List<String> notesJson = prefs.getStringList('local_notes') ?? [];

    // Find and replace the note
    List<String> updatedNotesJson = [];
    bool found = false;

    for (String noteJson in notesJson) {
      try {
        final Map<String, dynamic> noteMap = jsonDecode(noteJson);

        if (noteMap['id'] == note.id) {
          // Replace with updated note
          updatedNotesJson.add(jsonEncode(note.toJson()));
          found = true;
        } else {
          // Keep unchanged
          updatedNotesJson.add(noteJson);
        }
      } catch (e) {
        // Keep malformed notes
        updatedNotesJson.add(noteJson);
      }
    }

    // If note was not found, add it
    if (!found) {
      updatedNotesJson.add(jsonEncode(note.toJson()));
    }

    // Save back to SharedPreferences
    await prefs.setStringList('local_notes', updatedNotesJson);

    // Also add to pending uploads for syncing later
    await _addToPendingUploads(note);
  }

  // Mark a note as deleted locally
  Future<void> _markNoteAsDeletedLocally(String noteId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get deleted note IDs
    List<String> deletedNoteIds = prefs.getStringList('deleted_notes') ?? [];

    // Add this note ID to deleted list if not already there
    if (!deletedNoteIds.contains(noteId)) {
      deletedNoteIds.add(noteId);

      // Save back to SharedPreferences
      await prefs.setStringList('deleted_notes', deletedNoteIds);

      // Also add to pending deletes for syncing later
      await _addToPendingDeletes(noteId);
    }
  }

  // Add a note to pending uploads for later syncing
  Future<void> _addToPendingUploads(Note note) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get existing pending uploads
    List<String> pendingUploads = prefs.getStringList('pending_uploads') ?? [];

    // Remove any existing entries for this note
    pendingUploads.removeWhere((item) {
      try {
        final Map<String, dynamic> noteMap = jsonDecode(item);
        return noteMap['id'] == note.id;
      } catch (e) {
        return false;
      }
    });

    // Add the new note
    pendingUploads.add(jsonEncode(note.toJson()));

    // Save back to SharedPreferences
    await prefs.setStringList('pending_uploads', pendingUploads);
  }

  // Add a note ID to pending deletes for later syncing
  Future<void> _addToPendingDeletes(String noteId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get existing pending deletes
    List<String> pendingDeletes = prefs.getStringList('pending_deletes') ?? [];

    // Add note ID if not already there
    if (!pendingDeletes.contains(noteId)) {
      pendingDeletes.add(noteId);

      // Save back to SharedPreferences
      await prefs.setStringList('pending_deletes', pendingDeletes);
    }
  }

  // Sync all pending changes with Firestore
  Future<void> syncPendingChanges() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return; // Can't sync if offline
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Process pending deletes first
    List<String> pendingDeletes = prefs.getStringList('pending_deletes') ?? [];
    for (String noteId in pendingDeletes) {
      try {
        await _firestore.collection(_notesCollection).doc(noteId).delete();
      } catch (e) {
        // Skip if error (e.g., already deleted)
        continue;
      }
    }

    // Clear pending deletes
    await prefs.setStringList('pending_deletes', []);

    // Process pending uploads
    List<String> pendingUploads = prefs.getStringList('pending_uploads') ?? [];
    for (String noteJson in pendingUploads) {
      try {
        final Map<String, dynamic> noteMap = jsonDecode(noteJson);
        final Note note = Note.fromJson(noteMap);

        // Check if note exists
        final docSnapshot =
            await _firestore.collection(_notesCollection).doc(note.id).get();

        if (docSnapshot.exists) {
          // Update existing note
          await _firestore
              .collection(_notesCollection)
              .doc(note.id)
              .update(note.toFirestore());
        } else {
          // Create new note
          await _firestore
              .collection(_notesCollection)
              .doc(note.id)
              .set(note.toFirestore());
        }

        // Handle reminder notification
        if (note.reminderDateTime != null) {
          await _scheduleReminderNotification(note);
        }
      } catch (e) {
        // Skip if error
        continue;
      }
    }

    // Clear pending uploads
    await prefs.setStringList('pending_uploads', []);
  }
}
