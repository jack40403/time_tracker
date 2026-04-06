class FormatUtils {
  static String formatDuration(int totalSeconds) {
    if (totalSeconds == 0) return '0秒';
    
    final hrs = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    if (hrs > 0) return '${hrs}小時 ${mins}分';
    if (mins > 0) return '${mins}分鐘 ${secs}秒';
    return '${secs}秒';
  }

  static String formatDurationDetailed(int totalSeconds) {
    final hrs = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    
    List<String> parts = [];
    if (hrs > 0) parts.add('${hrs}時');
    if (mins > 0) parts.add('${mins}分');
    if (secs > 0 || parts.isEmpty) parts.add('${secs}秒');
    
    return parts.join(' ');
  }
}
