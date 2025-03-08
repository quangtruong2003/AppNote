import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../models/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../widgets/note_card.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({Key? key}) : super(key: key);

  @override
  _NotesListScreenState createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  bool _isSearchVisible = false;

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => Routes.onWillPop(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Notes'),
          automaticallyImplyLeading: false, // Loại bỏ nút back
          actions: [
            IconButton(
              icon: const Icon(Icons.star),
              onPressed: () {
                Navigator.pushNamed(context, '/premium');
              },
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.pushNamed(context, '/profile');
              },
            ),
          ],
        ),
        body: NotesListBody(isSearchVisible: _isSearchVisible),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/note-detail');
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class NotesListBody extends StatefulWidget {
  final bool isSearchVisible;

  const NotesListBody({Key? key, this.isSearchVisible = false})
    : super(key: key);

  @override
  _NotesListBodyState createState() => _NotesListBodyState();
}

class _NotesListBodyState extends State<NotesListBody> {
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Ensure notes load immediately when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotes();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId =
          Provider.of<AuthProvider>(context, listen: false).user?.uid;
      if (userId != null) {
        await Provider.of<NoteProvider>(
          context,
          listen: false,
        ).fetchNotes(userId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notes: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId =
          Provider.of<AuthProvider>(context, listen: false).user?.uid;
      if (userId != null) {
        await Provider.of<NoteProvider>(
          context,
          listen: false,
        ).fetchNotes(userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes refreshed successfully'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing notes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);
    List<Note> filteredNotes = noteProvider.notes;

    // Debug print to verify notes are loaded
    print('Loaded ${noteProvider.notes.length} notes');

    if (_searchQuery.isNotEmpty) {
      filteredNotes =
          filteredNotes
              .where(
                (note) =>
                    note.title.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    note.content.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();
    }

    return Column(
      children: [
        if (widget.isSearchVisible)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Notes',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                        : null,
              ),
              autofocus: true,
            ),
          ),
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredNotes.isEmpty
                  ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No notes found matching "${_searchQuery}"'
                          : 'No notes yet. Create one!',
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _refreshNotes,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        print('Displaying note: ${note.id} - ${note.title}');
                        // Replace NoteCard with custom card implementation
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InkWell(
                            onTap: () {
                              print(
                                'Tapped on note: ${note.id} - ${note.title}',
                              );
                              Navigator.pushNamed(
                                context,
                                '/note-detail',
                                arguments: note,
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (note.isPinned)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Icon(Icons.push_pin, size: 16),
                                        ),
                                      Expanded(
                                        child: Text(
                                          note.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (note.reminderDateTime != null)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.notifications,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              note.reminderDateTime!
                                                  .toString()
                                                  .substring(0, 16),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      Expanded(
                                        child: Text(
                                          note.updatedAt.toString().substring(
                                            0,
                                            16,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}
