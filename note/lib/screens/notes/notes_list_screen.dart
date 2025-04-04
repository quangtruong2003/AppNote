import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../models/note.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../widgets/note_card.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
          title: Text(
            'Ghi chú của tôi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.star_outline),
              tooltip: 'Phiên bản Premium',
              onPressed: () {
                Navigator.pushNamed(context, '/premium');
              },
            ),
            IconButton(
              icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
              tooltip: 'Tìm kiếm',
              onPressed: _toggleSearch,
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/profile');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildUserAvatar(context),
              ),
            ),
          ],
        ),
        body: NotesListBody(isSearchVisible: _isSearchVisible),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, '/note-detail');
          },
          icon: const Icon(Icons.add),
          label: const Text('Ghi chú mới'),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child:
          authProvider.user?.photoURL != null
              ? ClipOval(
                child: Image.network(
                  authProvider.user!.photoURL!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildAvatarFallback(authProvider);
                  },
                ),
              )
              : _buildAvatarFallback(authProvider),
    );
  }

  Widget _buildAvatarFallback(AuthProvider authProvider) {
    return Center(
      child: Text(
        authProvider.user?.displayName?.isNotEmpty == true
            ? authProvider.user!.displayName![0].toUpperCase()
            : authProvider.user?.email?.isNotEmpty == true
            ? authProvider.user!.email![0].toUpperCase()
            : 'U',
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
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

  /// Hàm chuyển đổi chuỗi có dấu thành không dấu
  String _removeDiacritics(String text) {
    var withDiacritics =
        'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ';
    var withoutDiacritics =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    String result = text;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);
    List<Note> filteredNotes = noteProvider.notes;
    final theme = Theme.of(context);

    // Cải tiến filter notes để hỗ trợ tìm kiếm không dấu
    if (_searchQuery.isNotEmpty) {
      String normalizedQuery = _removeDiacritics(_searchQuery.toLowerCase());

      filteredNotes =
          filteredNotes.where((note) {
            String normalizedTitle = _removeDiacritics(
              note.title.toLowerCase(),
            );
            String normalizedContent = _removeDiacritics(
              note.content.toLowerCase(),
            );

            return normalizedTitle.contains(normalizedQuery) ||
                normalizedContent.contains(normalizedQuery);
          }).toList();
    }

    return Column(
      children: [
        if (widget.isSearchVisible)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: widget.isSearchVisible ? 80 : 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  //labelText: 'Tìm kiếm ghi chú',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
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
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        Expanded(
          child:
              _isLoading
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Đang tải ghi chú...',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                  : filteredNotes.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.note_add,
                          size: 80,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Không tìm thấy ghi chú nào\nphù hợp với "${_searchQuery}"'
                              : 'Bạn chưa có ghi chú nào\nHãy tạo ghi chú mới!',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_searchQuery.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Tạo ghi chú'),
                              onPressed: () {
                                Navigator.pushNamed(context, '/note-detail');
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _refreshNotes,
                    color: theme.colorScheme.primary,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: GridView.builder(
                        padding: const EdgeInsets.only(top: 12.0, bottom: 80.0),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          final bool hasReminder =
                              note.reminderDateTime != null;

                          // Chọn màu ngẫu nhiên cho ghi chú từ bảng màu pastel
                          final List<Color> noteColors = [
                            Color(0xFFF8FAFF), // Trắng xanh nhạt
                            Color(0xFFFFF8E1), // Vàng nhạt
                            Color(0xFFF1F8E9), // Xanh lá nhạt
                            Color(0xFFE8F5E9), // Xanh lục nhạt
                            Color(0xFFE3F2FD), // Xanh dương nhạt
                            Color(0xFFF3E5F5), // Tím nhạt
                            Color(0xFFFFEBEE), // Hồng nhạt
                            Color(0xFFFFF3E0), // Cam nhạt
                          ];

                          final cardColor =
                              noteColors[index % noteColors.length];

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side:
                                  note.isPinned
                                      ? BorderSide(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      )
                                      : BorderSide.none,
                            ),
                            color: cardColor,
                            child: InkWell(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/note-detail',
                                  arguments: note,
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        if (note.isPinned)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 8),
                                            child: Icon(
                                              Icons.push_pin,
                                              size: 16,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            note.title,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Flexible(
                                      child: LayoutBuilder(
                                        builder: (
                                          BuildContext context,
                                          BoxConstraints constraints,
                                        ) {
                                          return SingleChildScrollView(
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minHeight:
                                                    constraints.maxHeight,
                                              ),
                                              child: MarkdownBody(
                                                data: note.content,
                                                fitContent: false,
                                                styleSheet: MarkdownStyleSheet(
                                                  p: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black
                                                        .withOpacity(0.8),
                                                  ),
                                                  strong: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                  em: const TextStyle(
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                  del: const TextStyle(
                                                    decoration:
                                                        TextDecoration
                                                            .lineThrough,
                                                  ),
                                                  code: TextStyle(
                                                    backgroundColor:
                                                        theme
                                                            .colorScheme
                                                            .surfaceVariant,
                                                    color:
                                                        theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (hasReminder)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  theme
                                                      .colorScheme
                                                      .primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.notifications,
                                                  size: 12,
                                                  color: Colors.deepPurple,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  note.reminderDateTime!
                                                      .toString()
                                                      .substring(0, 16),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        Flexible(
                                          child: Container(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              _formatDate(note.updatedAt),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.black54,
                                              ),
                                              textAlign: TextAlign.right,
                                              overflow: TextOverflow.ellipsis,
                                            ),
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
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
