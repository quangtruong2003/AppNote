import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';

class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isDirty = false;
  bool _isSaving = false;
  bool _isInitialized = false;
  Note? _note;
  DateTime? _reminderDateTime;
  bool _isPinned = false;
  Timer? _autoSaveTimer;
  bool _autoSaveEnabled = true;
  bool _showSavedIndicator = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNote();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeNote();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  void _initializeNote() {
    final args = ModalRoute.of(context)?.settings.arguments;
    print('Note Detail received argument: $args');

    if (args != null && args is Note) {
      // We have a valid note, combine title and content for editing
      print('Valid Note detected: ${args.id} - ${args.title}');
      setState(() {
        _note = args;
        _titleController.text = _note!.title;
        _contentController.text = _note!.content;
        _reminderDateTime = _note!.reminderDateTime;
        _isPinned = _note!.isPinned;
        _isInitialized = true;
      });
    } else {
      // No valid note, set up for creating new note
      print('No valid note argument, creating new note');
      setState(() {
        _note = null;
        _titleController.text = '';
        _contentController.text = '';
        _isInitialized = true;
      });
    }

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    // Focus the note input field
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  void _onTextChanged() {
    if (mounted && !_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }

    // Schedule auto-save
    if (_autoSaveEnabled) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(milliseconds: 1500), _autoSave);
    }
  }

  Future<void> _autoSave() async {
    if (!_isDirty || _isSaving) return;

    await _saveNote(showFeedback: false);
  }

  Future<void> _saveNote({bool showFeedback = true}) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Don't save empty notes during auto-save
    if (title.isEmpty && content.isEmpty) {
      return;
    }

    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;

    if (userId == null) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to save notes'),
          ),
        );
      }
      return;
    }

    // Set saving state
    setState(() {
      _isSaving = true;
    });

    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);

      if (_note == null) {
        // Create new note
        final newNote = await noteProvider.createNote(
          title: title,
          content: content,
          userId: userId,
          reminderDateTime: _reminderDateTime,
          isPinned: _isPinned,
        );

        // Update the local note reference
        setState(() {
          _note = newNote;
        });

        if (mounted && showFeedback) {
          _showSavedFeedback();
        }
      } else {
        // Update existing note
        final updatedNote = _note!.copyWith(
          title: title,
          content: content,
          reminderDateTime: _reminderDateTime,
          isPinned: _isPinned,
        );
        await noteProvider.updateNote(updatedNote);

        if (mounted && showFeedback) {
          _showSavedFeedback();
        }
      }

      if (mounted) {
        setState(() {
          _isDirty = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving note: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSavedFeedback() {
    setState(() {
      _showSavedIndicator = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSavedIndicator = false;
        });
      }
    });
  }

  Future<bool> _onWillPop() async {
    // Auto-save any pending changes
    if (_isDirty) {
      await _saveNote(showFeedback: false);
    }
    return true;
  }

  void _togglePinned() {
    setState(() {
      _isPinned = !_isPinned;
      _isDirty = true;
    });
    // Trigger auto-save when pin status changes
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: true, // Always allow pop since we auto-save
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final result = await _onWillPop();
        if (result && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_note == null ? 'New Note' : 'Edit Note'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _onWillPop();
              if (mounted) Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: _togglePinned,
            ),
            IconButton(
              icon: Icon(
                _reminderDateTime != null
                    ? Icons.notifications_active
                    : Icons.notifications_none,
              ),
              onPressed: _selectReminderDateTime,
            ),
            if (_isSaving)
              Container(
                width: 48,
                padding: const EdgeInsets.all(12),
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_showSavedIndicator)
              Container(
                width: 48,
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.check, color: Colors.green),
              ),
            if (_note != null)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _isSaving ? null : _deleteNote,
              ),
          ],
        ),
        body:
            _isSaving && !_autoSaveEnabled
                ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Saving note...'),
                    ],
                  ),
                )
                : Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          if (_reminderDateTime != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.notifications_active,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Reminder: ${_reminderDateTime.toString().substring(0, 16)}',
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: _CustomNoteEditor(
                              titleController: _titleController,
                              contentController: _contentController,
                              focusNode: _focusNode,
                              scrollController: _scrollController,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isSaving && _autoSaveEnabled)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Saving...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }

  Future<void> _selectReminderDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminderDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;

    if (!mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderDateTime ?? DateTime.now()),
    );

    if (pickedTime == null) return;

    final DateTime combinedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _reminderDateTime = combinedDateTime;
      _isDirty = true;
    });

    // Trigger auto-save when reminder is set
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Note'),
            content: const Text('Are you sure you want to delete this note?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true && _note != null) {
      try {
        await Provider.of<NoteProvider>(
          context,
          listen: false,
        ).deleteNote(_note!.id);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting note: ${e.toString()}')),
          );
        }
      }
    }
  }
}

class _CustomNoteEditor extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode focusNode;
  final ScrollController scrollController;

  const _CustomNoteEditor({
    required this.titleController,
    required this.contentController,
    required this.focusNode,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: titleController,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          maxLines: 1,
          decoration: const InputDecoration(
            hintText: 'Title',
            border: InputBorder.none,
          ),
        ),
        Expanded(
          child: TextField(
            controller: contentController,
            focusNode: focusNode,
            scrollController: scrollController,
            decoration: const InputDecoration(
              hintText: 'Type your note here...',
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 16),
            maxLines: null,
            keyboardType: TextInputType.multiline,
          ),
        ),
      ],
    );
  }
}
