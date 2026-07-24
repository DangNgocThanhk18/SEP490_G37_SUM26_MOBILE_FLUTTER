import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('vi')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  bool get isVietnamese => locale.languageCode == 'vi';

  String tr(String key, {Map<String, Object?> values = const {}}) {
    var value = isVietnamese ? (_vietnamese[key] ?? key) : key;
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return value;
  }
}

extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String tr(String key, {Map<String, Object?> values = const {}}) =>
      l10n.tr(key, values: values);

  String localizedError(Object error) {
    final message = error.toString();
    const connectPrefix =
        'Cannot connect to backend. Check that Spring Boot is running at ';
    if (message.startsWith(connectPrefix) && message.endsWith('.')) {
      return tr(
        'Cannot connect to backend. Check that Spring Boot is running at {url}.',
        values: {
          'url': message.substring(connectPrefix.length, message.length - 1),
        },
      );
    }
    const timeoutPrefix = 'Request timed out while connecting to ';
    if (message.startsWith(timeoutPrefix) && message.endsWith('.')) {
      return tr(
        'Request timed out while connecting to {url}.',
        values: {
          'url': message.substring(timeoutPrefix.length, message.length - 1),
        },
      );
    }
    return tr(message);
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const Map<String, String> _vietnamese = {
  '/ month': '/ tháng',
  '/ year': '/ năm',
  'Account': 'Tài khoản',
  'Action': 'Hành động',
  'Active until {date}': 'Có hiệu lực đến {date}',
  'Ad-free reading': 'Đọc truyện không quảng cáo',
  'All': 'Tất cả',
  'Alerts': 'Thông báo',
  'App Settings': 'Cài đặt ứng dụng',
  'Apply filters': 'Áp dụng bộ lọc',
  'Author': 'Tác giả',
  'Back': 'Quay lại',
  'Backend did not return an access token.':
      'Máy chủ không trả về mã truy cập.',
  'Backend returned invalid JSON.': 'Máy chủ trả về dữ liệu JSON không hợp lệ.',
  'By {author}': 'Bởi {author}',
  'Back to Top': 'Lên đầu trang',
  'Back to top': 'Lên đầu trang',
  'BEST VALUE': 'GIÁ TỐT NHẤT',
  'Cancel': 'Hủy',
  'Cannot connect to backend. Check that Spring Boot is running at {url}.':
      'Không thể kết nối máy chủ. Hãy kiểm tra Spring Boot đang chạy tại {url}.',
  'Cannot read chapter detail.': 'Không thể đọc chi tiết chương.',
  'Cannot read comic detail.': 'Không thể đọc chi tiết truyện.',
  'Cannot read discussion thread.': 'Không thể đọc cuộc thảo luận.',
  'Cannot read premium plan settings.': 'Không thể đọc cài đặt gói Premium.',
  'Cannot read profile response.': 'Không thể đọc thông tin hồ sơ.',
  'Change Password': 'Đổi mật khẩu',
  'Ch. {number}': 'Chương {number}',
  'Ch. {number}: {title}': 'Chương {number}: {title}',
  'Chapter': 'Chương',
  'Chapter {number}': 'Chương {number}',
  'Chapters': 'Các chương',
  'Close': 'Đóng',
  'Comic': 'Truyện tranh',
  'ComiVerse Reader': 'Trình đọc ComiVerse',
  'Comments': 'Bình luận',
  'Comments are not available from the current backend API.':
      'API hiện tại chưa hỗ trợ bình luận.',
  'Comic link copied.': 'Đã sao chép liên kết truyện.',
  'Completed': 'Hoàn thành',
  'Confirm': 'Xác nhận',
  'Confirm Premium upgrade': 'Xác nhận nâng cấp Premium',
  'Cannot load page {page}': 'Không thể tải trang {page}',
  'Choose your plan': 'Chọn gói của bạn',
  'Continue as Guest': 'Tiếp tục với tư cách khách',
  'Continue Reading': 'Đọc tiếp',
  'Continue reading': 'Đọc tiếp',
  'Continue with the {plan} plan?': 'Tiếp tục với gói {plan}?',
  'Current password': 'Mật khẩu hiện tại',
  'Daily': 'Ngày',
  'Dark': 'Tối',
  'Default': 'Mặc định',
  'Discussion': 'Thảo luận',
  'Display name': 'Tên hiển thị',
  'Done': 'Xong',
  'Download': 'Tải xuống',
  'Downloads': 'Nội dung đã tải',
  'Early chapter access': 'Đọc chương mới sớm',
  'Email': 'Email',
  'Email or username': 'Email hoặc tên đăng nhập',
  'End of chapter': 'Hết chương',
  'English': 'Tiếng Anh',
  'Enter your email or username': 'Nhập email hoặc tên đăng nhập',
  'Enter your password': 'Nhập mật khẩu',
  'Error': 'Lỗi',
  'Earlier This Week': 'Trong tuần này',
  'Explore': 'Khám phá',
  'Explore comics': 'Khám phá truyện',
  'Favorites': 'Yêu thích',
  'Filters': 'Bộ lọc',
  'Fit to width': 'Vừa chiều rộng',
  'Following': 'Đang theo dõi',
  'For You': 'Dành cho bạn',
  'Genre': 'Thể loại',
  'Help Center': 'Trung tâm trợ giúp',
  'Home': 'Trang chủ',
  'History': 'Lịch sử',
  'Information': 'Thông tin',
  'Interaction': 'Tương tác',
  'Language': 'Ngôn ngữ',
  'Language changed to English.': 'Đã chuyển sang Tiếng Anh.',
  'Language changed to Vietnamese.': 'Đã chuyển sang Tiếng Việt.',
  'Latest: Ch. {number}': 'Mới nhất: Chương {number}',
  'Library': 'Thư viện',
  'Light': 'Sáng',
  'Loading…': 'Đang tải…',
  'Like': 'Thích',
  'Liked': 'Đã thích',
  'Locked': 'Đã khóa',
  'Latest chapter {number}': 'Chương mới nhất {number}',
  'Manage Plan': 'Quản lý gói',
  'Mark all as read': 'Đánh dấu tất cả đã đọc',
  'Monthly': 'Tháng',
  'Most viewed': 'Xem nhiều nhất',
  'New': 'Mới',
  'New chapters': 'Chương mới',
  'New password': 'Mật khẩu mới',
  'New password must have at least 6 characters.':
      'Mật khẩu mới phải có ít nhất 6 ký tự.',
  'New Updates': 'Mới cập nhật',
  'Next': 'Tiếp theo',
  'No comments in this discussion yet.':
      'Chưa có bình luận trong cuộc thảo luận này.',
  'No chapter pages were returned by the backend.':
      'Máy chủ không trả về trang truyện nào.',
  'No comics match these filters.': 'Không có truyện phù hợp bộ lọc.',
  'No comics match this filter.': 'Không có truyện phù hợp bộ lọc.',
  'No notifications in this category.':
      'Không có thông báo trong danh mục này.',
  'No published chapters yet.': 'Chưa có chương nào được xuất bản.',
  'No published comics yet.': 'Chưa có truyện nào được xuất bản.',
  'No synopsis has been published yet.': 'Chưa có phần giới thiệu truyện.',
  'Notification Preferences': 'Tùy chọn thông báo',
  'Notifications': 'Thông báo',
  'Offline downloads are available with Premium.':
      'Tải xuống để đọc ngoại tuyến dành cho gói Premium.',
  'Now': 'Vừa xong',
  'Ongoing': 'Đang tiến hành',
  'Older': 'Cũ hơn',
  'Open': 'Mở',
  'Password': 'Mật khẩu',
  'Password updated.': 'Đã cập nhật mật khẩu.',
  'Personal Information': 'Thông tin cá nhân',
  'Popular': 'Phổ biến',
  'Premium Monthly': 'Premium theo tháng',
  'Premium Upgrade': 'Nâng cấp Premium',
  'Premium Yearly': 'Premium theo năm',
  'Previous': 'Trước',
  'Privacy Policy': 'Chính sách quyền riêng tư',
  'Profile': 'Hồ sơ',
  'Published': 'Đã xuất bản',
  'Read without limits': 'Đọc truyện không giới hạn',
  'Ranking': 'Xếp hạng',
  'Read Chapter {number}': 'Đọc chương {number}',
  'Read Now': 'Đọc ngay',
  'Read More': 'Đọc thêm',
  'Ready to read': 'Sẵn sàng để đọc',
  'Reading History': 'Lịch sử đọc',
  'Ranking data is not available yet.': 'Dữ liệu xếp hạng chưa khả dụng.',
  'Reader options': 'Tùy chọn đọc',
  'Recent': 'Gần đây',
  'Recently updated': 'Mới cập nhật',
  'Recommended for You': 'Đề xuất cho bạn',
  'Remove': 'Xóa',
  'Remove comic?': 'Xóa truyện?',
  'Remove “{title}” from this library list?':
      'Xóa “{title}” khỏi danh sách thư viện này?',
  'Remove “{title}” from your reading history?':
      'Xóa “{title}” khỏi lịch sử đọc?',
  'Remove from library': 'Xóa khỏi thư viện',
  'Removed from library.': 'Đã xóa khỏi thư viện.',
  'Retry': 'Thử lại',
  'Request failed': 'Yêu cầu thất bại',
  'Request timed out while connecting to {url}.':
      'Yêu cầu kết nối đến {url} đã hết thời gian chờ.',
  'Save': 'Lưu',
  'Saved': 'Đã lưu',
  'Search comics, authors, genres...': 'Tìm truyện, tác giả, thể loại...',
  'Select language': 'Chọn ngôn ngữ',
  'Share': 'Chia sẻ',
  'Share comic': 'Chia sẻ truyện',
  'Show results': 'Hiện kết quả',
  'Show Less': 'Thu gọn',
  'Sign In': 'Đăng nhập',
  'Sign Out': 'Đăng xuất',
  'Sign in': 'Đăng nhập',
  'Sign in to sync this action with your library.':
      'Đăng nhập để đồng bộ thao tác này với thư viện.',
  'Sign in to sync your ComiVerse account, or continue as guest to read public comics.':
      'Đăng nhập để đồng bộ tài khoản ComiVerse hoặc tiếp tục với tư cách khách để đọc truyện công khai.',
  'Sign in to manage your profile and Premium plan.':
      'Đăng nhập để quản lý hồ sơ và gói Premium.',
  'Sign in to receive chapter updates and account notifications.':
      'Đăng nhập để nhận cập nhật chương và thông báo tài khoản.',
  'Sign in to see notifications from your ComiVerse activity.':
      'Đăng nhập để xem thông báo từ hoạt động ComiVerse.',
  'Sign in to sync your saved, liked, and reading history.':
      'Đăng nhập để đồng bộ truyện đã lưu, đã thích và lịch sử đọc.',
  'Sign in to sync saved comics, favorites, and reading history.':
      'Đăng nhập để đồng bộ truyện đã lưu, yêu thích và lịch sử đọc.',
  'Sign out?': 'Đăng xuất?',
  'Sort by': 'Sắp xếp theo',
  'Status': 'Trạng thái',
  'Success': 'Thành công',
  'System': 'Hệ thống',
  'Start Premium': 'Bắt đầu Premium',
  'Switch Premium Plan': 'Đổi gói Premium',
  'Support & Privacy': 'Hỗ trợ và quyền riêng tư',
  'Terms of Service': 'Điều khoản dịch vụ',
  'Theme': 'Giao diện',
  'The referenced comment is unavailable.':
      'Bình luận được tham chiếu không còn khả dụng.',
  'This chapter is no longer available.': 'Chương này không còn khả dụng.',
  'This library section is empty.': 'Mục thư viện này đang trống.',
  'This notification is available in the web workspace.':
      'Thông báo này chỉ khả dụng trên phiên bản web.',
  'Today': 'Hôm nay',
  'Title': 'Tiêu đề',
  'Top rated': 'Đánh giá cao nhất',
  'Trending Now': 'Đang thịnh hành',
  'Update': 'Cập nhật',
  'Updated': 'Đã cập nhật',
  'Upgrade failed': 'Nâng cấp thất bại',
  'Unexpected backend response.': 'Phản hồi từ máy chủ không hợp lệ.',
  'Upgrade to ComiVerse Premium': 'Nâng cấp lên ComiVerse Premium',
  'Unlock the complete catalog, support creators, and enjoy a cleaner reading experience.':
      'Mở khóa toàn bộ kho truyện, hỗ trợ tác giả và tận hưởng trải nghiệm đọc tốt hơn.',
  'Use dark mode': 'Dùng giao diện tối',
  'Use light mode': 'Dùng giao diện sáng',
  'Username': 'Tên đăng nhập',
  'Unknown author': 'Không rõ tác giả',
  'Vertical scroll': 'Cuộn dọc',
  'View Comic': 'Xem truyện',
  'View Premium Plans': 'Xem các gói Premium',
  'View all': 'Xem tất cả',
  'Vietnamese': 'Tiếng Việt',
  'Warning': 'Cảnh báo',
  'Weekly': 'Tuần',
  'Welcome back': 'Chào mừng trở lại',
  'Welcome to Premium': 'Chào mừng đến với Premium',
  'Yearly': 'Năm',
  'Your Collection': 'Bộ sưu tập của bạn',
  'Your Premium plan is now active.': 'Gói Premium của bạn đã được kích hoạt.',
  'Plan availability and prices are loaded from ComiVerse system settings.':
      'Gói và mức giá được tải từ cài đặt hệ thống ComiVerse.',
  'Your current session will be closed.':
      'Phiên đăng nhập hiện tại sẽ được đóng.',
  '{count} chapters': '{count} chương',
  '{count}d': '{count} ngày',
  '{count}h': '{count} giờ',
  '{count}m': '{count} phút',
  '{count} views': '{count} lượt xem',
  '· {count} chapters': '· {count} chương',
  '· {count} views': '· {count} lượt xem',
  ' · {count} views': ' · {count} lượt xem',
  'views': 'lượt xem',
};
