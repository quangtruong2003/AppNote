import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool _autoSaveEnabled = true;
  bool _showSavedIndicator = false;
  bool _showFormatToolbar = false;
  Color _noteColor = Colors.white;
  final List<Color> _availableColors = [
    Colors.white,
    const Color(0xFFF8FAFF), // Trắng xanh nhạt
    const Color(0xFFFFF8E1), // Vàng nhạt
    const Color(0xFFF1F8E9), // Xanh lá nhạt
    const Color(0xFFE8F5E9), // Xanh lục nhạt
    const Color(0xFFE3F2FD), // Xanh dương nhạt
    const Color(0xFFF3E5F5), // Tím nhạt
    const Color(0xFFFFEBEE), // Hồng nhạt
    const Color(0xFFFFF3E0), // Cam nhạt
  ];

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

    if (args != null && args is Note) {
      setState(() {
        _note = args;
        _titleController.text = _note!.title;
        _contentController.text = _note!.content;
        _reminderDateTime = _note!.reminderDateTime;
        _isPinned = _note!.isPinned;
        _isInitialized = true;

        // Khôi phục màu sắc nếu có
        if (_note!.color != null) {
          _noteColor = Color(_note!.color ?? 0xFFFFFFFF);
        }
      });
    } else {
      setState(() {
        _note = null;
        _titleController.text = '';
        _contentController.text = '';
        _isInitialized = true;
      });
    }

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    // Focus vào trường nhập liệu
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

    // Lên lịch tự động lưu
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

    // Không lưu ghi chú trống trong quá trình tự động lưu
    if (title.isEmpty && content.isEmpty) {
      return;
    }

    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;

    if (userId == null) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn cần đăng nhập để lưu ghi chú')),
        );
      }
      return;
    }

    // Đặt trạng thái đang lưu
    setState(() {
      _isSaving = true;
    });

    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);

      if (_note == null) {
        // Tạo ghi chú mới
        final newNote = await noteProvider.createNote(
          title: title,
          content: content,
          userId: userId,
          reminderDateTime: _reminderDateTime,
          isPinned: _isPinned,
          color: _noteColor.value,
        );

        // Cập nhật tham chiếu ghi chú cục bộ
        setState(() {
          _note = newNote;
        });

        if (mounted && showFeedback) {
          _showSavedFeedback();
        }
      } else {
        // Cập nhật ghi chú hiện có
        final updatedNote = _note!.copyWith(
          title: title,
          content: content,
          reminderDateTime: _reminderDateTime,
          isPinned: _isPinned,
          color: _noteColor.value,
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
              content: Text('Lỗi khi lưu ghi chú: ${e.toString()}'),
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
    // Tự động lưu các thay đổi đang chờ xử lý
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
    // Kích hoạt tự động lưu khi trạng thái ghim thay đổi
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  void _toggleFormatToolbar() {
    setState(() {
      _showFormatToolbar = !_showFormatToolbar;
    });
  }

  Future<void> _shareNote() async {
    if (_note == null &&
        _titleController.text.isEmpty &&
        _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể chia sẻ ghi chú trống')),
      );
      return;
    }

    final title =
        _titleController.text.isEmpty
            ? 'Ghi chú không tiêu đề'
            : _titleController.text;
    final content = _contentController.text;

    // Sao chép nội dung ghi chú vào clipboard thay vì dùng Share
    await Clipboard.setData(ClipboardData(text: '$title\n\n$content'));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép ghi chú vào clipboard để chia sẻ'),
        ),
      );
    }
  }

  void _selectNoteColor() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chọn màu ghi chú',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children:
                      _availableColors.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _noteColor = color;
                              _isDirty = true;
                            });
                            Navigator.pop(context);
                            _autoSaveTimer?.cancel();
                            _autoSaveTimer = Timer(
                              const Duration(milliseconds: 500),
                              _autoSave,
                            );
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    color == _noteColor
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey,
                                width: color == _noteColor ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
    );
  }

  void _insertBulletPoint() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final cursorPos = selection.baseOffset;

    if (cursorPos >= 0) {
      final beforeCursor = text.substring(0, cursorPos);
      final afterCursor = text.substring(cursorPos);
      final prefix =
          beforeCursor.isEmpty || beforeCursor.endsWith('\n') ? '' : '\n';

      final textToInsert = "$prefix• ";
      final newText = beforeCursor + textToInsert + afterCursor;

      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: cursorPos + textToInsert.length,
        ),
      );
    }
  }

  void _insertNumberedPoint() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final cursorPos = selection.baseOffset;

    if (cursorPos >= 0) {
      final beforeCursor = text.substring(0, cursorPos);
      final afterCursor = text.substring(cursorPos);
      final prefix =
          beforeCursor.isEmpty || beforeCursor.endsWith('\n') ? '' : '\n';

      final lines = beforeCursor.split('\n');
      final lineCount = lines.length;
      final textToInsert = "${prefix}${lineCount + 1}. ";
      final newText = beforeCursor + textToInsert + afterCursor;

      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: cursorPos + textToInsert.length,
        ),
      );
    }
  }

  void _insertQuote() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final cursorPos = selection.baseOffset;

    if (cursorPos >= 0) {
      final beforeCursor = text.substring(0, cursorPos);
      final afterCursor = text.substring(cursorPos);
      final prefix =
          beforeCursor.isEmpty || beforeCursor.endsWith('\n') ? '' : '\n';

      final textToInsert = "$prefix> ";
      final newText = beforeCursor + textToInsert + afterCursor;

      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: cursorPos + textToInsert.length,
        ),
      );
    }
  }

  void _insertHeading() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final cursorPos = selection.baseOffset;

    if (cursorPos >= 0) {
      final beforeCursor = text.substring(0, cursorPos);
      final afterCursor = text.substring(cursorPos);
      final prefix =
          beforeCursor.isEmpty || beforeCursor.endsWith('\n') ? '' : '\n';

      final textToInsert = "${prefix}# ";
      final newText = beforeCursor + textToInsert + afterCursor;

      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: cursorPos + textToInsert.length,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: true, // Luôn cho phép quay lại vì chúng ta tự động lưu
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Theme(
        data: Theme.of(context).copyWith(scaffoldBackgroundColor: _noteColor),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: _noteColor,
            elevation: 0,
            title: Text(_note == null ? 'Ghi chú mới' : 'Chỉnh sửa ghi chú'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Quay lại',
              onPressed: () async {
                await _onWillPop();
                if (mounted) Navigator.pop(context);
              },
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                tooltip: 'Ghim ghi chú',
                onPressed: _togglePinned,
              ),
              IconButton(
                icon: Icon(
                  _showFormatToolbar
                      ? Icons.format_align_left
                      : Icons.format_bold,
                ),
                tooltip: 'Định dạng văn bản',
                onPressed: _toggleFormatToolbar,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Tùy chọn khác',
                onSelected: (value) {
                  switch (value) {
                    case 'color':
                      _selectNoteColor();
                      break;
                    case 'share':
                      _shareNote();
                      break;
                    case 'reminder':
                      _selectReminderDateTime();
                      break;
                    case 'delete':
                      _deleteNote();
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'color',
                        child: Row(
                          children: [
                            Icon(
                              Icons.color_lens,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Đổi màu ghi chú'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'reminder',
                        child: Row(
                          children: [
                            Icon(
                              _reminderDateTime != null
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _reminderDateTime != null
                                  ? 'Thay đổi nhắc nhở'
                                  : 'Đặt nhắc nhở',
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(
                              Icons.share,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Chia sẻ ghi chú'),
                          ],
                        ),
                      ),
                      if (_note != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text(
                                'Xóa ghi chú',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                    ],
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
            ],
          ),
          body: Stack(
            children: [
              Container(
                color: _noteColor,
                child: Column(
                  children: [
                    // Hiển thị nhắc nhở
                    if (_reminderDateTime != null)
                      Container(
                        margin: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: 8,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_active,
                              size: 20,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nhắc nhở: ${_formatDateTime(_reminderDateTime!)}',
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                              ),
                              onPressed: () {
                                setState(() {
                                  _reminderDateTime = null;
                                  _isDirty = true;
                                });
                                _autoSaveTimer?.cancel();
                                _autoSaveTimer = Timer(
                                  const Duration(milliseconds: 500),
                                  _autoSave,
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                    // Thanh công cụ định dạng đơn giản
                    if (_showFormatToolbar)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(26),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.format_list_bulleted),
                                  tooltip: 'Danh sách',
                                  onPressed: _insertBulletPoint,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.format_list_numbered),
                                  tooltip: 'Danh sách số',
                                  onPressed: _insertNumberedPoint,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.format_quote),
                                  tooltip: 'Trích dẫn',
                                  onPressed: _insertQuote,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.title),
                                  tooltip: 'Tiêu đề',
                                  onPressed: _insertHeading,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.color_lens),
                                  tooltip: 'Màu ghi chú',
                                  onPressed: _selectNoteColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Trình chỉnh sửa ghi chú
                    Expanded(
                      child: Container(
                        color: _noteColor,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Tiêu đề
                            TextField(
                              controller: _titleController,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                              maxLines: null,
                              decoration: const InputDecoration(
                                hintText: 'Tiêu đề',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 16),

                            // Nội dung
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _contentController,
                                  scrollController: _scrollController,
                                  focusNode: _focusNode,
                                  maxLines: null,
                                  expands: true,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Nhập nội dung ghi chú của bạn...',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String formattedDate;
    if (dateToCheck == today) {
      formattedDate = 'Hôm nay';
    } else if (dateToCheck == tomorrow) {
      formattedDate = 'Ngày mai';
    } else {
      formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$formattedDate, $hour:$minute';
  }

  Future<void> _selectReminderDateTime() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        _reminderDateTime ?? now.add(const Duration(minutes: 30));

    // Hiển thị dialog chọn ngày
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    if (!mounted) return;

    // Hiển thị dialog chọn giờ
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
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

    // Kích hoạt tự động lưu khi nhắc nhở được đặt
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), _autoSave);

    // Hiển thị thông báo xác nhận
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã đặt nhắc nhở: ${_formatDateTime(combinedDateTime)}',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa ghi chú'),
            content: const Text('Bạn có chắc chắn muốn xóa ghi chú này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );

    if (confirmed == true && _note != null) {
      try {
        setState(() {
          _isSaving = true;
        });

        await Provider.of<NoteProvider>(
          context,
          listen: false,
        ).deleteNote(_note!.id);

        if (mounted) {
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa ghi chú'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi xóa ghi chú: ${e.toString()}')),
          );
        }
      }
    }
  }
}
