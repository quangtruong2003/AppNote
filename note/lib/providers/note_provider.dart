import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_service.dart';

class NoteProvider extends ChangeNotifier {
  final NoteService _noteService = NoteService();
  List<Note> _notes = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Note> get notes {
    // Sort by isPinned first, then by updatedAt
    final sortedNotes = [..._notes];
    sortedNotes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt); // Latest first
    });
    return sortedNotes;
  }

  List<Note> get pinnedNotes => _notes.where((note) => note.isPinned).toList();
  List<Note> get unpinnedNotes =>
      _notes.where((note) => !note.isPinned).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch all notes for a user
  Future<void> fetchNotes(String userId) async {
    _setLoading(true);

    try {
      final fetchedNotes = await _noteService.getNotes(userId);
      _notes = fetchedNotes;
      _error = null;
    } catch (e) {
      _error = 'Failed to fetch notes: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  // Create a new note
  Future<Note> createNote({
    required String title,
    required String content,
    required String userId,
    DateTime? reminderDateTime,
    bool isPinned = false,
    int? color,
  }) async {
    _setLoading(true);

    try {
      final newNote = Note(
        userId: userId,
        title: title,
        content: content,
        isPinned: isPinned,
        reminderDateTime: reminderDateTime,
        color: color,
      );

      final createdNote = await _noteService.addNote(newNote);
      _notes.add(createdNote);
      _error = null;
      notifyListeners();
      return createdNote;
    } catch (e) {
      _error = 'Failed to create note: ${e.toString()}';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Update an existing note
  Future<Note> updateNote(Note updatedNote) async {
    _setLoading(true);

    try {
      final savedNote = await _noteService.updateNote(updatedNote);

      // Replace the old note with the updated one
      final index = _notes.indexWhere((note) => note.id == savedNote.id);
      if (index != -1) {
        _notes[index] = savedNote;
      }

      _error = null;
      notifyListeners();
      return savedNote;
    } catch (e) {
      _error = 'Failed to update note: ${e.toString()}';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a note
  Future<void> deleteNote(String noteId) async {
    _setLoading(true);

    try {
      await _noteService.deleteNote(noteId);

      // Remove the deleted note from the list
      _notes.removeWhere((note) => note.id == noteId);

      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete note: ${e.toString()}';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Get a note by ID
  Note? getNote(String noteId) {
    try {
      return _notes.firstWhere((note) => note.id == noteId);
    } catch (e) {
      return null;
    }
  }

  // Search notes
  List<Note> searchNotes(String query) {
    if (query.isEmpty) return notes;

    final lowercaseQuery = query.toLowerCase();
    return _notes.where((note) {
      return note.title.toLowerCase().contains(lowercaseQuery) ||
          note.content.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Toggle pin status
  Future<void> togglePin(String noteId) async {
    final noteIndex = _notes.indexWhere((note) => note.id == noteId);

    if (noteIndex == -1) return;

    final note = _notes[noteIndex];
    final updatedNote = note.copyWith(isPinned: !note.isPinned);

    await updateNote(updatedNote);
  }

  // Helper method to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
