import 'package:flutter/material.dart';

import '../models/social_models.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import '../widgets/messenger_avatar.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _socialService = SocialService();
  final _searchController = TextEditingController();

  List<FriendUser> _friends = [];
  List<FriendRequest> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _socialService.getFriends(),
        _socialService.getFriendRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<FriendUser>;
        _requests = results[1] as List<FriendRequest>;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat(FriendUser friend) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
    );
    if (mounted) _loadData();
  }

  Future<void> _openRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendRequestsScreen(
          initialRequests: _requests,
          onChanged: _loadData,
        ),
      ),
    );
    if (mounted) _loadData();
  }

  Future<void> _openAddFriend() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFriendScreen()),
    );
    if (mounted) _loadData();
  }

  List<FriendUser> get _filteredFriends {
    final query = _searchController.text.trim().toLowerCase();
    final friends = [..._friends]
      ..sort(
        (a, b) => a.fullName
            .toLowerCase()
            .compareTo(b.fullName.toLowerCase()),
      );
    if (query.isEmpty) return friends;
    return friends
        .where(
          (friend) =>
              friend.fullName.toLowerCase().contains(query) ||
              friend.email.toLowerCase().contains(query),
        )
        .toList();
  }

  Map<String, List<FriendUser>> get _groupedFriends {
    final grouped = <String, List<FriendUser>>{};
    for (final friend in _filteredFriends) {
      final name = friend.fullName.trim();
      final key = _sectionKey(name);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(friend);
    }
    return grouped;
  }

  String _sectionKey(String name) {
    if (name.isEmpty) return '#';
    final firstLetter = name[0].toUpperCase();
    const normalized = {
      'Á': 'A',
      'À': 'A',
      'Ả': 'A',
      'Ã': 'A',
      'Ạ': 'A',
      'Ă': 'A',
      'Ắ': 'A',
      'Ằ': 'A',
      'Ẳ': 'A',
      'Ẵ': 'A',
      'Ặ': 'A',
      'Â': 'A',
      'Ấ': 'A',
      'Ầ': 'A',
      'Ẩ': 'A',
      'Ẫ': 'A',
      'Ậ': 'A',
      'Đ': 'D',
      'É': 'E',
      'È': 'E',
      'Ẻ': 'E',
      'Ẽ': 'E',
      'Ẹ': 'E',
      'Ê': 'E',
      'Ế': 'E',
      'Ề': 'E',
      'Ể': 'E',
      'Ễ': 'E',
      'Ệ': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Ỉ': 'I',
      'Ĩ': 'I',
      'Ị': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ỏ': 'O',
      'Õ': 'O',
      'Ọ': 'O',
      'Ô': 'O',
      'Ố': 'O',
      'Ồ': 'O',
      'Ổ': 'O',
      'Ỗ': 'O',
      'Ộ': 'O',
      'Ơ': 'O',
      'Ớ': 'O',
      'Ờ': 'O',
      'Ở': 'O',
      'Ỡ': 'O',
      'Ợ': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Ủ': 'U',
      'Ũ': 'U',
      'Ụ': 'U',
      'Ư': 'U',
      'Ứ': 'U',
      'Ừ': 'U',
      'Ử': 'U',
      'Ữ': 'U',
      'Ự': 'U',
      'Ý': 'Y',
      'Ỳ': 'Y',
      'Ỷ': 'Y',
      'Ỹ': 'Y',
      'Ỵ': 'Y',
    };
    final key = normalized[firstLetter] ?? firstLetter;
    return RegExp(r'[A-Z]').hasMatch(key) ? key : '#';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bạn bè'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _openAddFriend,
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Kết bạn',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Tìm bạn bè',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
            _FriendRequestBar(
              count: _requests.length,
              onTap: _openRequests,
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _loadData);
    }
    if (_filteredFriends.isEmpty) {
      return _EmptyState(
        icon: Icons.people_outline,
        title: _searchController.text.trim().isEmpty
            ? 'Chưa có bạn bè'
            : 'Không tìm thấy bạn bè',
        message: _searchController.text.trim().isEmpty
            ? 'Lời mời đã chấp nhận sẽ xuất hiện tại đây.'
            : 'Thử tìm bằng tên hoặc email khác.',
      );
    }

    final groups = _groupedFriends.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: groups.length,
        itemBuilder: (context, groupIndex) {
          final group = groups[groupIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: const Color(0xFFF5F6F8),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Text(
                  group.key,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (var i = 0; i < group.value.length; i++)
                _FriendTile(
                  friend: group.value[i],
                  online: (group.value[i].id + i).isEven,
                  onTap: () => _openChat(group.value[i]),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _socialService = SocialService();
  final _searchController = TextEditingController();

  List<UserSearchResult> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Nhập ít nhất 2 ký tự để tìm bạn bè.');
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _socialService.searchUsers(query);
      if (mounted) setState(() => _results = results);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(UserSearchResult user) async {
    try {
      await _socialService.sendFriendRequest(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi lời mời kết bạn')),
      );
      await _search();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Kết bạn'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Nhập tên hoặc email để tìm bạn bè',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          onPressed: _search,
                          icon: const Icon(Icons.arrow_forward),
                          tooltip: 'Tìm kiếm',
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  border: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const _EmptyState(
        icon: Icons.person_search,
        title: 'Tìm bạn mới',
        message: 'Nhập tên hoặc email rồi nhấn tìm kiếm để gửi lời mời.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _results[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: MessengerAvatar(name: user.fullName, size: 48),
          title: Text(
            user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _relationshipAction(user),
        );
      },
    );
  }

  Widget _relationshipAction(UserSearchResult user) {
    return switch (user.relationshipStatus) {
      'ACCEPTED' => const Chip(label: Text('Bạn bè')),
      'OUTGOING' => const Chip(label: Text('Đã gửi')),
      'INCOMING' => const Chip(label: Text('Đã mời bạn')),
      _ => IconButton.filled(
          onPressed: () => _sendRequest(user),
          icon: const Icon(Icons.person_add),
          tooltip: 'Kết bạn',
        ),
    };
  }
}

class FriendRequestsScreen extends StatefulWidget {
  final List<FriendRequest> initialRequests;
  final Future<void> Function()? onChanged;

  const FriendRequestsScreen({
    super.key,
    this.initialRequests = const [],
    this.onChanged,
  });

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final _socialService = SocialService();
  late List<FriendRequest> _requests;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requests = widget.initialRequests;
    if (_requests.isEmpty) _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _socialService.getFriendRequests();
      if (mounted) setState(() => _requests = requests);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(FriendRequest request, String action) async {
    try {
      await _socialService.respondToFriendRequest(request.id, action);
      if (!mounted) return;
      setState(() => _requests.removeWhere((item) => item.id == request.id));
      await widget.onChanged?.call();
      final accepted = action == 'ACCEPT';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted ? 'Đã chấp nhận lời mời' : 'Đã từ chối lời mời',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Lời mời kết bạn'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _loadRequests);
    }
    if (_requests.isEmpty) {
      return const _EmptyState(
        icon: Icons.how_to_reg,
        title: 'Không có lời mời',
        message: 'Các lời mời kết bạn chưa xử lý sẽ xuất hiện tại đây.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final request = _requests[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                MessengerAvatar(name: request.fullName, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    request.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => _respond(request, 'REJECT'),
                  child: const Text('Từ chối'),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: () => _respond(request, 'ACCEPT'),
                  child: const Text('Chấp nhận'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FriendRequestBar extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FriendRequestBar({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFEAF2FF),
              child: Icon(Icons.person_add_alt_1, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Lời mời kết bạn ($count)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final FriendUser friend;
  final bool online;
  final VoidCallback onTap;

  const _FriendTile({
    required this.friend,
    required this.online,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: MessengerAvatar(name: friend.fullName, size: 48, online: online),
      title: Text(
        friend.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        online ? 'Đang hoạt động' : 'Không hoạt động',
        style: const TextStyle(color: Color(0xFF6B7280)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF2563EB)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 52, color: Color(0xFF2563EB)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
