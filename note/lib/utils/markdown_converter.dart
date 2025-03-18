// Lớp hỗ trợ xử lý định dạng Markdown
class MarkdownHelper {
  // Phát hiện và đánh dấu định dạng Markdown trong văn bản
  static bool isTextFormatted(String text, int position) {
    // Kiểm tra xem vị trí hiện tại có nằm trong phạm vi định dạng không
    
    // Kiểm tra in đậm
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    for (final match in boldPattern.allMatches(text)) {
      if (match.start <= position && position <= match.end) {
        return true;
      }
    }
    
    // Kiểm tra in nghiêng
    final italicPattern = RegExp(r'\*(.+?)\*');
    for (final match in italicPattern.allMatches(text)) {
      if (match.start <= position && position <= match.end) {
        return true;
      }
    }
    
    return false;
  }
  
  // Áp dụng định dạng in đậm
  static String applyBold(String text, int start, int end) {
    final selectedText = text.substring(start, end);
    
    // Kiểm tra xem văn bản đã được định dạng in đậm chưa
    if (selectedText.startsWith('**') && selectedText.endsWith('**')) {
      // Nếu đã in đậm, bỏ định dạng
      final unformattedText = selectedText.substring(2, selectedText.length - 2);
      return text.replaceRange(start, end, unformattedText);
    } else {
      // Nếu chưa in đậm, thêm định dạng
      final formattedText = '**$selectedText**';
      return text.replaceRange(start, end, formattedText);
    }
  }
  
  // Áp dụng định dạng in nghiêng
  static String applyItalic(String text, int start, int end) {
    final selectedText = text.substring(start, end);
    
    // Kiểm tra xem văn bản đã được định dạng in nghiêng chưa
    if (selectedText.startsWith('*') && selectedText.endsWith('*') && 
        !(selectedText.startsWith('**') && selectedText.endsWith('**'))) {
      // Nếu đã in nghiêng, bỏ định dạng
      final unformattedText = selectedText.substring(1, selectedText.length - 1);
      return text.replaceRange(start, end, unformattedText);
    } else {
      // Nếu chưa in nghiêng, thêm định dạng
      final formattedText = '*$selectedText*';
      return text.replaceRange(start, end, formattedText);
    }
  }
  
  // Áp dụng định dạng gạch ngang
  static String applyStrikethrough(String text, int start, int end) {
    final selectedText = text.substring(start, end);
    
    // Kiểm tra xem văn bản đã được định dạng gạch ngang chưa
    if (selectedText.startsWith('~~') && selectedText.endsWith('~~')) {
      // Nếu đã gạch ngang, bỏ định dạng
      final unformattedText = selectedText.substring(2, selectedText.length - 2);
      return text.replaceRange(start, end, unformattedText);
    } else {
      // Nếu chưa gạch ngang, thêm định dạng
      final formattedText = '~~$selectedText~~';
      return text.replaceRange(start, end, formattedText);
    }
  }
  
  // Áp dụng định dạng khối mã
  static String applyCodeBlock(String text, int start, int end) {
    final selectedText = text.substring(start, end);
    
    // Kiểm tra xem văn bản đã được định dạng khối mã chưa
    if (selectedText.startsWith('`') && selectedText.endsWith('`')) {
      // Nếu đã là khối mã, bỏ định dạng
      final unformattedText = selectedText.substring(1, selectedText.length - 1);
      return text.replaceRange(start, end, unformattedText);
    } else {
      // Nếu chưa là khối mã, thêm định dạng
      final formattedText = '`$selectedText`';
      return text.replaceRange(start, end, formattedText);
    }
  }

  // Áp dụng danh sách đánh dấu đầu dòng
  static String applyBulletList(String text, int start, int end) {
    final selectedText = text.substring(start, end);
    final lines = selectedText.split('\n');
    final bulletedLines = lines.map((line) => 
        line.trim().isEmpty ? line : line.trimLeft().startsWith('* ') 
            ? line.trimLeft().substring(2) // Loại bỏ dấu * nếu đã có
            : '* $line' // Thêm dấu * nếu chưa có
    ).join('\n');
    
    return text.replaceRange(start, end, bulletedLines);
  }
  
  // Áp dụng danh sách đánh số
  static String applyNumberedList(String text, int start, int end) {
    final selectedText = text.substring(start, end);
    final lines = selectedText.split('\n');
    
    final numberedLines = <String>[];
    int number = 1;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        numberedLines.add(line);
      } else {
        // Kiểm tra xem dòng đã có định dạng danh sách đánh số chưa
        final match = RegExp(r'^\s*\d+\.\s').firstMatch(line);
        if (match != null) {
          // Nếu đã có, loại bỏ định dạng
          numberedLines.add(line.replaceFirst(RegExp(r'^\s*\d+\.\s'), ''));
        } else {
          // Nếu chưa có, thêm định dạng
          numberedLines.add('$number. $line');
          number++;
        }
      }
    }
    
    return text.replaceRange(start, end, numberedLines.join('\n'));
  }
  
  // Áp dụng định dạng trích dẫn
  static String applyQuote(String text, int start, int end) {
    final selectedText = text.substring(start, end);
    final lines = selectedText.split('\n');
    final quotedLines = lines.map((line) => 
        line.trim().isEmpty ? line : line.trimLeft().startsWith('> ') 
            ? line.trimLeft().substring(2) // Loại bỏ dấu > nếu đã có
            : '> $line' // Thêm dấu > nếu chưa có
    ).join('\n');
    
    return text.replaceRange(start, end, quotedLines);
  }
  
  // Áp dụng định dạng tiêu đề
  static String applyHeading(String text, int start, int end) {
    final selectedText = text.substring(start, end);
    final lines = selectedText.split('\n');
    
    if (lines.isEmpty) return text;
    
    // Chỉ áp dụng tiêu đề cho dòng đầu tiên
    final firstLine = lines[0];
    if (firstLine.trimLeft().startsWith('# ')) {
      // Nếu đã là tiêu đề, bỏ định dạng
      lines[0] = firstLine.trimLeft().substring(2);
    } else {
      // Nếu chưa là tiêu đề, thêm định dạng
      lines[0] = '# $firstLine';
    }
    
    return text.replaceRange(start, end, lines.join('\n'));
  }
} 