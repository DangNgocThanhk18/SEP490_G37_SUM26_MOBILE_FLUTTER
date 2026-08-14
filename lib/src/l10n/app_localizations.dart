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
  'Show featured comic {number}: {title}':
      'Xem truy\u1ec7n n\u1ed5i b\u1eadt {number}: {title}',
  'Comic rating': '\u0110\u00e1nh gi\u00e1 truy\u1ec7n',
  '/ 5 ({count} rating)': '/ 5 ({count} \u0111\u00e1nh gi\u00e1)',
  '/ 5 ({count} ratings)': '/ 5 ({count} \u0111\u00e1nh gi\u00e1)',
  'Your rating: {score}/5':
      '\u0110\u00e1nh gi\u00e1 c\u1ee7a b\u1ea1n: {score}/5',
  'Rate {score} star': 'Ch\u1ea5m {score} sao',
  'Rate {score} stars': 'Ch\u1ea5m {score} sao',
  '(Selected {score} stars)': '(\u0110\u00e3 ch\u1ecdn {score} sao)',
  '(Tap a star to rate)':
      '(Ch\u1ea1m v\u00e0o sao \u0111\u1ec3 \u0111\u00e1nh gi\u00e1)',
  'Sign in to rate this comic.':
      '\u0110\u0103ng nh\u1eadp \u0111\u1ec3 \u0111\u00e1nh gi\u00e1 truy\u1ec7n n\u00e0y.',
  'Rated {score} stars successfully.':
      '\u0110\u00e3 \u0111\u00e1nh gi\u00e1 {score} sao th\u00e0nh c\u00f4ng.',
  'Remove your rating?': 'X\u00f3a \u0111\u00e1nh gi\u00e1 c\u1ee7a b\u1ea1n?',
  'Are you sure you want to remove your rating for this comic?':
      'B\u1ea1n c\u00f3 ch\u1eafc mu\u1ed1n x\u00f3a \u0111\u00e1nh gi\u00e1 c\u1ee7a m\u00ecnh cho truy\u1ec7n n\u00e0y kh\u00f4ng?',
  'Remove rating': 'X\u00f3a \u0111\u00e1nh gi\u00e1',
  'Keep rating': 'Gi\u1eef \u0111\u00e1nh gi\u00e1',
  'Your rating has been removed.':
      '\u0110\u00e1nh gi\u00e1 c\u1ee7a b\u1ea1n \u0111\u00e3 \u0111\u01b0\u1ee3c x\u00f3a.',
  'Remove my rating': 'X\u00f3a \u0111\u00e1nh gi\u00e1 c\u1ee7a t\u00f4i',
  '/ month': '/ tháng',
  '/ year': '/ năm',
  'Account': 'Tài khoản',
  'Action': 'Hành động',
  'Active until {date}': 'Có hiệu lực đến {date}',
  'Ad-free reading': 'Đọc truyện không quảng cáo',
  'All': 'Tất cả',
  'Alerts': 'Thông báo',
  'App Settings': 'Cài đặt ứng dụng',
  'Screen capture protection': 'Bảo vệ chụp màn hình',
  'Presentation build setting': 'Tùy chọn dành cho bản trình chiếu',
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
  'Comic page. Pinch or double tap to zoom.':
      'Trang truyện. Chụm hai ngón hoặc chạm hai lần để thu phóng.',
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
  'Encrypted Premium chapters': 'Chương Premium được mã hóa',
  'Secure offline downloads are available in the configured Android and iOS apps.':
      'Tải xuống ngoại tuyến an toàn khả dụng trên ứng dụng Android và iOS đã được cấu hình.',
  'Download chapters': 'Tải chương truyện',
  'Premium is verified by the server. Offline access must be renewed every 7 days.':
      'Premium được máy chủ xác minh. Quyền đọc ngoại tuyến phải được gia hạn mỗi 7 ngày.',
  'Download complete': 'Tải xuống hoàn tất',
  'Download failed': 'Tải xuống thất bại',
  'Download again': 'Tải lại',
  'Chapter {number} is ready to read offline.':
      'Chương {number} đã sẵn sàng để đọc ngoại tuyến.',
  'Offline access renewed': 'Đã gia hạn quyền đọc ngoại tuyến',
  'This chapter can be read offline for up to 7 more days.':
      'Chương này có thể được đọc ngoại tuyến thêm tối đa 7 ngày.',
  'Renewal failed': 'Gia hạn thất bại',
  'Remove download?': 'Xóa nội dung tải xuống?',
  'Remove Chapter {number} from this device?':
      'Xóa Chương {number} khỏi thiết bị này?',
  'No chapters are downloaded on this device.':
      'Chưa có chương nào được tải xuống thiết bị này.',
  'Downloaded chapters stay encrypted. Connect to the Internet at least once every 7 days to verify Premium access.':
      'Các chương đã tải luôn được mã hóa. Hãy kết nối Internet ít nhất một lần mỗi 7 ngày để xác minh quyền Premium.',
  'Offline until {date}': 'Đọc ngoại tuyến đến {date}',
  'Renew offline access': 'Gia hạn quyền đọc ngoại tuyến',
  'Remove download': 'Xóa nội dung tải xuống',
  'Manage offline devices': 'Quản lý thiết bị ngoại tuyến',
  'Offline devices': 'Thiết bị ngoại tuyến',
  'No offline devices are registered.':
      'Chưa có thiết bị ngoại tuyến nào được đăng ký.',
  'Current device': 'Thiết bị hiện tại',
  'Login devices': 'Thiết bị đăng nhập',
  'Up to 3 verified mobile devices': 'Tối đa 3 thiết bị di động đã xác minh',
  'No verified mobile devices.': 'Chưa có thiết bị di động nào được xác minh.',
  'Device limit reached': 'Đã đạt giới hạn thiết bị',
  'ComiVerse allows up to 3 mobile devices. Select one device to remove, then enter the OTP sent to your email.':
      'ComiVerse cho phép tối đa 3 thiết bị di động. Chọn một thiết bị để xóa rồi nhập OTP được gửi đến email của bạn.',
  'Previously verified': 'Đã xác minh trước đây',
  'Last active {date}': 'Hoạt động gần nhất {date}',
  'Email OTP': 'OTP qua email',
  'Enter the 6-digit OTP.': 'Nhập OTP gồm 6 chữ số.',
  'Remove login device?': 'Xóa thiết bị đăng nhập?',
  'Enter the OTP sent to your email to remove {device}. Offline access on that device will also be revoked.':
      'Nhập OTP được gửi đến email để xóa {device}. Quyền đọc ngoại tuyến trên thiết bị đó cũng sẽ bị thu hồi.',
  'Login device removed.': 'Đã xóa thiết bị đăng nhập.',
  'Could not remove device': 'Không thể xóa thiết bị',
  'Push status is temporarily unavailable.':
      'Tạm thời không thể kiểm tra trạng thái thông báo đẩy.',
  'Checking push delivery...': 'Đang kiểm tra thông báo đẩy...',
  'Push delivery is not configured on the server.':
      'Máy chủ chưa được cấu hình thông báo đẩy.',
  'This account has no registered push device.':
      'Tài khoản này chưa có thiết bị nhận thông báo đẩy.',
  'Push delivery is ready on {count} device(s).':
      'Thông báo đẩy đã sẵn sàng trên {count} thiết bị.',
  'Last verified {date}': 'Xác minh gần nhất {date}',
  'Revoke offline device?': 'Thu hồi thiết bị ngoại tuyến?',
  'This is the current device. Revoking it removes all local downloads and requires device enrollment again.':
      'Đây là thiết bị hiện tại. Việc thu hồi sẽ xóa toàn bộ nội dung tải xuống và yêu cầu đăng ký thiết bị lại.',
  'This device will no longer be able to renew or open its downloaded chapters.':
      'Thiết bị này sẽ không thể gia hạn hoặc mở các chương đã tải.',
  'Revoke': 'Thu hồi',
  'Device revoked': 'Đã thu hồi thiết bị',
  'Offline access was removed from that device.':
      'Quyền đọc ngoại tuyến đã bị xóa khỏi thiết bị đó.',
  'Could not revoke device': 'Không thể thu hồi thiết bị',
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
  'Most liked': 'Được thích nhiều nhất',
  'Most followed': 'Được theo dõi nhiều nhất',
  'Most bookmarked': 'Được lưu nhiều nhất',
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
  'Reader': 'Độc giả',
  'Translator': 'Dịch giả',
  'Project Leader': 'Trưởng nhóm dịch',
  'Staff': 'Nhân viên',
  'Administrator': 'Quản trị viên',
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
  'Recently added': 'Mới thêm',
  'Load more': 'Tải thêm',
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
  'Profile photos': 'Ảnh hồ sơ',
  'Profile photo': 'Ảnh đại diện',
  'Profile background': 'Ảnh nền hồ sơ',
  'Current profile photo': 'Ảnh đại diện hiện tại',
  'Selected profile photo': 'Ảnh đại diện đã chọn',
  'Current profile background': 'Ảnh nền hồ sơ hiện tại',
  'Selected profile background': 'Ảnh nền hồ sơ đã chọn',
  'Choose profile photo': 'Chọn ảnh đại diện',
  'Choose profile background': 'Chọn ảnh nền hồ sơ',
  'JPG, PNG, GIF or WebP up to 2MB.': 'JPG, PNG, GIF hoặc WebP, tối đa 2MB.',
  'JPG, PNG, GIF or WebP up to 4MB.': 'JPG, PNG, GIF hoặc WebP, tối đa 4MB.',
  'Please choose a JPG, PNG, GIF, or WebP image.':
      'Vui lòng chọn ảnh JPG, PNG, GIF hoặc WebP.',
  'Avatar image must be 2MB or smaller.':
      'Ảnh đại diện phải có dung lượng tối đa 2MB.',
  'Background image must be 4MB or smaller.':
      'Ảnh nền phải có dung lượng tối đa 4MB.',
  'Could not open the selected image.': 'Không thể mở ảnh đã chọn.',
  'Selected image is empty.': 'Ảnh đã chọn không có dữ liệu.',
  'Cannot read uploaded image response.': 'Không thể đọc kết quả tải ảnh lên.',
  'Image upload failed': 'Tải ảnh lên thất bại',
  'Uploading images...': 'Đang tải ảnh lên...',
  'Saving profile...': 'Đang lưu hồ sơ...',
  'Uploading...': 'Đang tải lên...',
  'Bio': 'Giới thiệu',
  'Cannot read notification preferences.': 'Không thể đọc tùy chọn thông báo.',
  'Cannot read updated profile response.': 'Không thể đọc hồ sơ vừa cập nhật.',
  'Choose which in-app notifications you receive.':
      'Chọn các thông báo trong ứng dụng mà bạn muốn nhận.',
  'Clear': 'Xóa',
  'Coming soon': 'Sắp có',
  'Date of birth': 'Ngày sinh',
  'Display name is required.': 'Vui lòng nhập tên hiển thị.',
  'Edit profile': 'Chỉnh sửa hồ sơ',
  'Forum activity': 'Hoạt động diễn đàn',
  'Comment replies': 'Phản hồi bình luận',
  'Forum': 'Diễn đàn',
  'Community': 'Cộng đồng',
  'ComiVerse Community': 'Cộng đồng ComiVerse',
  'Refresh': 'Làm mới',
  'Search discussions...': 'Tìm kiếm thảo luận...',
  'Latest discussions': 'Thảo luận mới nhất',
  'New post': 'Bài viết mới',
  'Start a discussion': 'Bắt đầu thảo luận',
  'Share ideas, ask questions, and meet other readers.':
      'Chia sẻ ý tưởng, đặt câu hỏi và kết nối với những độc giả khác.',
  '{count} threads': '{count} chủ đề',
  '{count} community threads': '{count} chủ đề cộng đồng',
  'No discussions yet.': 'Chưa có cuộc thảo luận nào.',
  'No discussions match your search.':
      'Không có cuộc thảo luận phù hợp với tìm kiếm.',
  'Sign in to join the community discussion.':
      'Đăng nhập để tham gia thảo luận cộng đồng.',
  'Discussion published.': 'Đã đăng cuộc thảo luận.',
  'Category': 'Danh mục',
  'General': 'Chung',
  'What would you like to discuss?': 'Bạn muốn thảo luận điều gì?',
  'Please enter a thread title.': 'Vui lòng nhập tiêu đề chủ đề.',
  'Please enter a thread description.': 'Vui lòng nhập nội dung thảo luận.',
  'Publish discussion': 'Đăng thảo luận',
  'Recently': 'Gần đây',
  'No notification preferences are available.':
      'Không có tùy chọn thông báo khả dụng.',
  'Not set': 'Chưa thiết lập',
  'Notification preferences saved.': 'Đã lưu tùy chọn thông báo.',
  'Profile updated.': 'Đã cập nhật hồ sơ.',
  'Project opportunities': 'Cơ hội dự án',
  'Review queue': 'Hàng chờ kiểm duyệt',
  'Save changes': 'Lưu thay đổi',
  'Save preferences': 'Lưu tùy chọn',
  'Select theme': 'Chọn giao diện',
  'Some sections could not be loaded.': 'Một số nội dung chưa thể tải.',
  'Submission status': 'Trạng thái nội dung gửi duyệt',
  'System announcements': 'Thông báo hệ thống',
  'System default': 'Theo hệ thống',
  'Team join requests': 'Yêu cầu tham gia nhóm',
  'Team updates': 'Cập nhật nhóm',
  'Plan availability and prices are loaded from ComiVerse system settings.':
      'Gói và mức giá được tải từ cài đặt hệ thống ComiVerse.',
  'Your current session will be closed.':
      'Phiên đăng nhập hiện tại sẽ được đóng.',
  'How can we help?': 'Chúng tôi có thể giúp gì cho bạn?',
  'Find quick answers or contact the ComiVerse support team.':
      'Tìm câu trả lời nhanh hoặc liên hệ đội ngũ hỗ trợ ComiVerse.',
  'Frequently Asked Questions': 'Câu hỏi thường gặp',
  'How do I save comics and sync my progress?':
      'Làm thế nào để lưu truyện và đồng bộ tiến độ?',
  'Sign in, then use Save or Favorite on a comic. Your library and reading progress will be synced with your account.':
      'Hãy đăng nhập, sau đó chọn Lưu hoặc Yêu thích trên truyện. Thư viện và tiến độ đọc sẽ được đồng bộ với tài khoản của bạn.',
  'How can I change the app language or theme?':
      'Làm thế nào để đổi ngôn ngữ hoặc giao diện?',
  'Open Profile, then choose Language or Theme under App Settings. Changes are applied immediately and kept for future sessions.':
      'Mở Hồ sơ, sau đó chọn Ngôn ngữ hoặc Giao diện trong Cài đặt ứng dụng. Thay đổi được áp dụng ngay và lưu cho những lần sử dụng sau.',
  'Why can I not connect to the server?':
      'Tại sao tôi không thể kết nối máy chủ?',
  'Check your internet connection and try again. When developing locally, make sure Spring Boot is running and the API base URL is correct for your device.':
      'Hãy kiểm tra kết nối mạng và thử lại. Khi phát triển cục bộ, hãy chắc chắn Spring Boot đang chạy và URL API phù hợp với thiết bị.',
  'How do notification preferences work?':
      'Tùy chọn thông báo hoạt động như thế nào?',
  'Open Profile and select Notification Preferences. You can enable or disable each notification category available for your account role.':
      'Mở Hồ sơ và chọn Tùy chọn thông báo. Bạn có thể bật hoặc tắt từng loại thông báo dành cho vai trò tài khoản của mình.',
  'How do I report inappropriate content?':
      'Làm thế nào để báo cáo nội dung không phù hợp?',
  'Send the comic, chapter, comment, or discussion link to our support email with a short description. The moderation team will review it.':
      'Gửi liên kết truyện, chương, bình luận hoặc thảo luận tới email hỗ trợ kèm mô tả ngắn. Đội ngũ kiểm duyệt sẽ xem xét.',
  'Still need help?': 'Bạn vẫn cần trợ giúp?',
  'Email us and include your account email, device, and a short description of the issue. We usually respond within 24 hours on business days.':
      'Hãy gửi email kèm email tài khoản, thiết bị và mô tả ngắn về sự cố. Chúng tôi thường phản hồi trong 24 giờ vào ngày làm việc.',
  'Copy support email': 'Sao chép email hỗ trợ',
  'Support email copied.': 'Đã sao chép email hỗ trợ.',
  'Last updated: July 2026': 'Cập nhật lần cuối: tháng 7 năm 2026',
  'Questions about this document?': 'Bạn có câu hỏi về tài liệu này?',
  'Contact the ComiVerse support team at {email}.':
      'Liên hệ đội ngũ hỗ trợ ComiVerse tại {email}.',
  'This policy explains what information ComiVerse collects, why we use it, and the choices available to you.':
      'Chính sách này giải thích thông tin ComiVerse thu thập, lý do sử dụng và các lựa chọn dành cho bạn.',
  '1. Information We Collect': '1. Thông tin chúng tôi thu thập',
  'We collect account information you provide, such as your username, email, display name, profile details, and authentication data. We also store activity needed for the service, including saved comics, likes, reading history, comments, notification preferences, and Premium status.':
      'Chúng tôi thu thập thông tin tài khoản bạn cung cấp như tên đăng nhập, email, tên hiển thị, hồ sơ và dữ liệu xác thực. Chúng tôi cũng lưu hoạt động cần thiết cho dịch vụ, gồm truyện đã lưu, lượt thích, lịch sử đọc, bình luận, tùy chọn thông báo và trạng thái Premium.',
  '2. How We Use Information': '2. Cách chúng tôi sử dụng thông tin',
  'We use this information to operate your account, synchronize your library, personalize recommendations, deliver notifications, process Premium features, improve reliability, and protect ComiVerse from fraud or abuse.':
      'Chúng tôi dùng thông tin này để vận hành tài khoản, đồng bộ thư viện, cá nhân hóa đề xuất, gửi thông báo, cung cấp tính năng Premium, cải thiện độ ổn định và bảo vệ ComiVerse khỏi gian lận hoặc lạm dụng.',
  '3. Sharing and Service Providers': '3. Chia sẻ và nhà cung cấp dịch vụ',
  'We do not sell your personal information. Data may be processed by service providers that help us host, secure, monitor, or deliver ComiVerse. We may disclose information when required by law or to protect users and the platform.':
      'Chúng tôi không bán thông tin cá nhân của bạn. Dữ liệu có thể được xử lý bởi các nhà cung cấp hỗ trợ lưu trữ, bảo mật, giám sát hoặc vận hành ComiVerse. Chúng tôi có thể cung cấp thông tin khi pháp luật yêu cầu hoặc để bảo vệ người dùng và nền tảng.',
  '4. Storage and Security': '4. Lưu trữ và bảo mật',
  'We use reasonable technical and organizational safeguards to protect your information. No online service can guarantee absolute security, so keep your password private and notify support if you suspect unauthorized access.':
      'Chúng tôi áp dụng các biện pháp kỹ thuật và tổ chức hợp lý để bảo vệ thông tin. Không dịch vụ trực tuyến nào đảm bảo an toàn tuyệt đối, vì vậy hãy giữ kín mật khẩu và báo cho hỗ trợ nếu nghi ngờ truy cập trái phép.',
  '5. Your Choices and Rights': '5. Lựa chọn và quyền của bạn',
  'You can update profile details and notification preferences in the app. You may also request access to, correction of, or deletion of your personal information by contacting support, subject to legal and operational retention requirements.':
      'Bạn có thể cập nhật hồ sơ và tùy chọn thông báo trong ứng dụng. Bạn cũng có thể yêu cầu truy cập, chỉnh sửa hoặc xóa thông tin cá nhân bằng cách liên hệ hỗ trợ, tùy theo yêu cầu lưu trữ pháp lý và vận hành.',
  'Please read these terms before accessing or using ComiVerse.':
      'Vui lòng đọc các điều khoản này trước khi truy cập hoặc sử dụng ComiVerse.',
  '1. Acceptance of Terms': '1. Chấp nhận điều khoản',
  'By accessing or using ComiVerse, you agree to these Terms of Service and our Privacy Policy. If you do not agree, do not use the service. These terms apply to visitors, registered users, and content contributors.':
      'Khi truy cập hoặc sử dụng ComiVerse, bạn đồng ý với Điều khoản dịch vụ và Chính sách quyền riêng tư này. Nếu không đồng ý, vui lòng không sử dụng dịch vụ. Các điều khoản áp dụng cho khách truy cập, người dùng đã đăng ký và người đóng góp nội dung.',
  '2. User Accounts': '2. Tài khoản người dùng',
  'You must provide accurate account information and safeguard your credentials. You are responsible for activity under your account and should notify us immediately of unauthorized use. We may suspend or terminate accounts that violate these terms.':
      'Bạn phải cung cấp thông tin tài khoản chính xác và bảo vệ thông tin đăng nhập. Bạn chịu trách nhiệm cho hoạt động trong tài khoản và cần báo ngay khi có truy cập trái phép. Chúng tôi có thể đình chỉ hoặc chấm dứt tài khoản vi phạm điều khoản.',
  '3. Content Guidelines': '3. Nguyên tắc nội dung',
  'You retain ownership of original content you submit. By publishing it, you grant ComiVerse a non-exclusive license to display, distribute, and promote it through the service. Content must not violate intellectual property rights or contain illegal, harmful, offensive, or misleading material.':
      'Bạn giữ quyền sở hữu nội dung gốc đã gửi. Khi xuất bản, bạn cấp cho ComiVerse quyền không độc quyền để hiển thị, phân phối và quảng bá nội dung qua dịch vụ. Nội dung không được vi phạm quyền sở hữu trí tuệ hoặc chứa tài liệu bất hợp pháp, gây hại, xúc phạm hay sai lệch.',
  '4. Prohibited Activities': '4. Hoạt động bị cấm',
  'You may not access another account without permission, scrape data, upload malicious code, impersonate others, bypass security controls, manipulate service metrics, or disrupt normal platform operation. Violations may lead to content removal or account termination.':
      'Bạn không được truy cập tài khoản khác khi chưa được phép, thu thập dữ liệu tự động, tải mã độc, mạo danh, vượt qua kiểm soát bảo mật, thao túng số liệu hoặc làm gián đoạn hoạt động nền tảng. Vi phạm có thể dẫn đến xóa nội dung hoặc chấm dứt tài khoản.',
  '5. Limitation of Liability': '5. Giới hạn trách nhiệm',
  'To the extent permitted by law, ComiVerse is not liable for indirect, incidental, special, consequential, or punitive damages resulting from your use of the service. Our total liability will not exceed the amount you paid to ComiVerse in the previous twelve months.':
      'Trong phạm vi pháp luật cho phép, ComiVerse không chịu trách nhiệm cho thiệt hại gián tiếp, ngẫu nhiên, đặc biệt, hệ quả hoặc mang tính trừng phạt phát sinh từ việc sử dụng dịch vụ. Tổng trách nhiệm không vượt quá số tiền bạn đã thanh toán cho ComiVerse trong mười hai tháng trước đó.',
  '{count} chapters': '{count} chương',
  '{count}d': '{count} ngày',
  '{count}h': '{count} giờ',
  '{count}m': '{count} phút',
  '{count} views': '{count} lượt xem',
  '· {count} chapters': '· {count} chương',
  '· {count} views': '· {count} lượt xem',
  ' · {count} views': ' · {count} lượt xem',
  'Cannot read the created comment.': 'Không thể đọc bình luận vừa tạo.',
  'Chapter {number} discussion': 'Thảo luận chương {number}',
  'Comment deleted.': 'Đã xóa bình luận.',
  'Comment posted.': 'Đã đăng bình luận.',
  'Delete': 'Xóa',
  'Delete comment?': 'Xóa bình luận?',
  'Hide replies': 'Ẩn phản hồi',
  'Join the chapter discussion': 'Tham gia thảo luận chương',
  'Load more comments': 'Tải thêm bình luận',
  'No comments yet. Start the conversation.':
      'Chưa có bình luận. Hãy bắt đầu cuộc trò chuyện.',
  'No replies yet.': 'Chưa có phản hồi.',
  'Post comment': 'Đăng bình luận',
  'Post reply': 'Đăng phản hồi',
  'Reply': 'Phản hồi',
  'Reply posted.': 'Đã đăng phản hồi.',
  'Replying to {name}': 'Đang phản hồi {name}',
  'Share your thoughts…': 'Chia sẻ suy nghĩ của bạn…',
  'Sign in to join the discussion.': 'Đăng nhập để tham gia thảo luận.',
  'Sign in to view and join the discussion.':
      'Đăng nhập để xem và tham gia thảo luận.',
  'This action cannot be undone.': 'Không thể hoàn tác thao tác này.',
  'Top': 'Lên đầu',
  'View replies': 'Xem phản hồi',
  'Write a reply…': 'Viết phản hồi…',
  'Premium chapter': 'Chương Premium',
  'Upgrade your plan to unlock this chapter and continue reading.':
      'Nâng cấp gói để mở khóa chương này và tiếp tục đọc.',
  'Sign in to upgrade and unlock Premium chapters.':
      'Đăng nhập để nâng cấp và mở khóa các chương Premium.',
  'View Premium plans': 'Xem các gói Premium',
  'Cannot read the created forum reply.':
      'Không thể đọc phản hồi diễn đàn vừa tạo.',
  'This discussion is locked.': 'Cuộc thảo luận này đã bị khóa.',
  'Write a comment…': 'Viết bình luận…',
  'views': 'lượt xem',
};
