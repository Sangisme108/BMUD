import 'package:flutter/material.dart';

import '../models/social_models.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import '../widgets/messenger_avatar.dart';
import 'account_recovery_request_screen.dart';
import 'chat_screen.dart';
import 'friends_screen.dart';
import 'login_history_screen.dart';
import 'login_screen.dart';
import 'security_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? userJson;

  const HomeScreen({super.key, this.userJson});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  int _selectedIndex = 0;
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (widget.userJson != null) {
      setState(() => _user = User.fromJson(widget.userJson!));
      return;
    }
    final savedUser = await _authService.getSavedUser();
    if (mounted) setState(() => _user = savedUser);
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChatsTab(user: _user),
      const NotificationsTab(),
      ProfileTab(user: _user, onLogout: _logout),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Đoạn chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Thông báo',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tôi',
          ),
        ],
      ),
    );
  }
}

class ChatsTab extends StatefulWidget {
  final User? user;

  const ChatsTab({super.key, this.user});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final _socialService = SocialService();
  final _searchController = TextEditingController();
  List<FriendUser> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conversations = await _socialService.getConversations();
      if (mounted) setState(() => _conversations = conversations);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FriendUser> get _filteredConversations {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _conversations;
    return _conversations
        .where(
          (item) =>
              item.fullName.toLowerCase().contains(query) ||
              item.email.toLowerCase().contains(query) ||
              (item.lastMessage ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _openChat(FriendUser friend) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
    );
    if (mounted) _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadConversations,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildStories()),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: _StateMessage(
                  icon: Icons.wifi_off,
                  title: 'Không tải được đoạn chat',
                  message: _error!,
                  actionLabel: 'Thử lại',
                  onAction: _loadConversations,
                ),
              )
            else if (_filteredConversations.isEmpty)
              SliverFillRemaining(
                child: _StateMessage(
                  icon: Icons.mark_chat_unread_outlined,
                  title: 'Chưa có đoạn chat',
                  message: 'Hãy tìm bạn bè và bắt đầu cuộc trò chuyện bảo mật.',
                  actionLabel: 'Tìm bạn bè',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendsScreen()),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: _filteredConversations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final friend = _filteredConversations[index];
                  return _ConversationTile(
                    friend: friend,
                    onTap: () => _openChat(friend),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              MessengerAvatar(name: widget.user?.fullName ?? 'BMUD', size: 42),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Đoạn chat',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filled(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendsScreen()),
                ),
                icon: const Icon(Icons.edit_square),
                tooltip: 'Tạo cuộc trò chuyện',
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Tìm kiếm bạn bè hoặc tin nhắn...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStories() {
    final friends = _conversations.take(12).toList();
    if (friends.isEmpty) {
      return const SizedBox(height: 8);
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final friend = friends[index];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openChat(friend),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  MessengerAvatar(
                    name: friend.fullName,
                    size: 58,
                    online: index.isEven,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    friend.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final FriendUser friend;
  final VoidCallback onTap;

  const _ConversationTile({required this.friend, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = friend.unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Dismissible(
        key: ValueKey(friend.id),
        background: _SwipeAction(
          color: theme.colorScheme.primary,
          icon: Icons.mark_email_read,
          label: 'Đã đọc',
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _SwipeAction(
          color: theme.colorScheme.error,
          icon: Icons.delete_outline,
          label: 'Xóa',
          alignment: Alignment.centerRight,
        ),
        confirmDismiss: (_) async => false,
        child: Card(
          elevation: 0,
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            leading: MessengerAvatar(
              name: friend.fullName,
              size: 56,
              online: true,
            ),
            title: Text(
              friend.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              friend.lastMessage ?? friend.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            trailing: SizedBox(
              width: 54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _timeLabel(friend.lastMessageAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 3),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        friend.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.push_pin_outlined, size: 16),
                ],
              ),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _SwipeAction extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  const _SwipeAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      _NotificationItem(
        Icons.person_add_alt,
        'Lời mời kết bạn',
        'Bạn có lời mời kết bạn mới đang chờ xử lý.',
        'Vừa xong',
      ),
      _NotificationItem(
        Icons.mark_chat_unread,
        'Tin nhắn mới',
        'Một người bạn vừa gửi tin nhắn bảo mật.',
        '3 phút',
      ),
      _NotificationItem(
        Icons.devices_other,
        'Thiết bị mới đăng nhập',
        'Hệ thống phát hiện đăng nhập từ thiết bị lạ.',
        '10 phút',
      ),
      _NotificationItem(
        Icons.password,
        'OTP xác minh',
        'Mã OTP đã được gửi về Gmail để xác minh thiết bị.',
        '15 phút',
      ),
      _NotificationItem(
        Icons.warning_amber,
        'Cảnh báo bảo mật',
        'Risk Scoring đánh giá lần đăng nhập này có rủi ro cao.',
        'Hôm nay',
      ),
      _NotificationItem(
        Icons.lock_clock,
        'Đăng nhập thất bại',
        'Tài khoản sẽ bị khóa sau 5 lần sai mật khẩu.',
        'Hôm qua',
      ),
      _NotificationItem(
        Icons.check_circle,
        'Đổi mật khẩu thành công',
        'Mật khẩu tài khoản đã được cập nhật.',
        'Hôm qua',
      ),
    ];

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
        itemCount: notifications.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              children: [
                const Expanded(
                  child: Text(
                    'Thông báo',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.done_all),
                  label: const Text('Đã đọc'),
                ),
              ],
            );
          }
          final item = notifications[index - 1];
          return Card(
            elevation: 0,
            child: ListTile(
              leading: CircleAvatar(child: Icon(item.icon)),
              title: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(item.body),
              trailing: SizedBox(
                width: 76,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        item.time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    SizedBox.square(
                      dimension: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {},
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Xóa',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  final User? user;
  final VoidCallback onLogout;

  const ProfileTab({super.key, this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ProfileAction(Icons.history, 'Lịch sử đăng nhập', () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginHistoryScreen()),
        );
      }),
      _ProfileAction(Icons.devices, 'Thiết bị đã đăng nhập', () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DevicesScreen()),
        );
      }),
      _ProfileAction(Icons.verified_user, 'Xác minh 2 lớp (2FA)', () {}),
      _ProfileAction(Icons.password, 'Đổi mật khẩu', () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AccountRecoveryRequestScreen(
              type: RecoveryRequestType.resetPassword,
            ),
          ),
        );
      }),
      _ProfileAction(Icons.key, 'Mã khôi phục tài khoản', () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AccountRecoveryRequestScreen(
              type: RecoveryRequestType.unlockAccount,
            ),
          ),
        );
      }),
      _ProfileAction(Icons.sms_outlined, 'Mã khôi phục tin nhắn', () {}),
      _ProfileAction(Icons.people, 'Danh sách bạn bè', () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendsScreen()),
        );
      }),
      _ProfileAction(Icons.privacy_tip, 'Quyền riêng tư', () {}),
      _ProfileAction(Icons.security, 'Bảo mật', () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SecurityDashboardScreen()),
        );
      }),
      _ProfileAction(Icons.settings, 'Cài đặt', () {}),
      _ProfileAction(Icons.logout, 'Đăng xuất', onLogout, destructive: true),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
        children: [
          const Text(
            'Tôi',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 22),
          Center(
            child: Column(
              children: [
                MessengerAvatar(name: user?.fullName ?? 'User', size: 96),
                const SizedBox(height: 14),
                Text(
                  user?.fullName ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(user?.email ?? ''),
                const SizedBox(height: 4),
                Text(
                  'Số điện thoại: Chưa cập nhật',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit),
                  label: const Text('Chỉnh sửa hồ sơ'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Card(
            elevation: 0,
            child: Column(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  ListTile(
                    leading: Icon(
                      actions[i].icon,
                      color: actions[i].destructive
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    title: Text(
                      actions[i].label,
                      style: TextStyle(
                        color: actions[i].destructive
                            ? Theme.of(context).colorScheme.error
                            : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: actions[i].onTap,
                  ),
                  if (i != actions.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final devices = [
      ('Android', 'Pixel Emulator', '10.0.2.15', 'Đang hoạt động'),
      ('iPhone', 'iPhone 15', '192.168.1.20', 'Hôm qua'),
      ('Web Browser', 'Chrome Windows', '103.xxx.xxx.xxx', '3 ngày trước'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Thiết bị đã đăng nhập')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: devices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final device = devices[index];
          return Card(
            elevation: 0,
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  device.$1 == 'Android'
                      ? Icons.android
                      : device.$1 == 'iPhone'
                          ? Icons.phone_iphone
                          : Icons.language,
                ),
              ),
              title: Text(device.$2),
              subtitle: Text('IP: ${device.$3}\nHoạt động cuối: ${device.$4}'),
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Đăng xuất'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String body;
  final String time;

  const _NotificationItem(this.icon, this.title, this.body, this.time);
}

class _ProfileAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ProfileAction(
    this.icon,
    this.label,
    this.onTap, {
    this.destructive = false,
  });
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
