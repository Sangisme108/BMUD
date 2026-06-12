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
  List<UserSearchResult> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
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
        _socialService.getConversations(),
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

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      _showMessage('Nhập ít nhất 2 ký tự');
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await _socialService.searchUsers(query);
      if (mounted) setState(() => _searchResults = results);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(UserSearchResult user) async {
    try {
      await _socialService.sendFriendRequest(user.id);
      _showMessage('Đã gửi lời mời kết bạn');
      await _search();
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _respond(FriendRequest request, String action) async {
    try {
      await _socialService.respondToFriendRequest(request.id, action);
      _showMessage(
        action == 'ACCEPT' ? 'Đã chấp nhận lời mời' : 'Đã từ chối lời mời',
      );
      await _loadData();
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Bạn bè',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Bạn bè'),
              Tab(icon: Icon(Icons.person_add_alt), text: 'Lời mời'),
              Tab(icon: Icon(Icons.search), text: 'Tìm kiếm'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadData)
                : TabBarView(
                    children: [
                      _buildFriends(),
                      _buildRequests(),
                      _buildSearch(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFriends() {
    if (_friends.isEmpty) {
      return const _EmptyState(
        icon: Icons.people_outline,
        title: 'Chưa có bạn bè',
        message: 'Tìm tài khoản bằng tên hoặc email để gửi lời mời kết bạn.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final friend = _friends[index];
          return Card(
            elevation: 0,
            child: ListTile(
              leading: MessengerAvatar(
                name: friend.fullName,
                online: index.isEven,
              ),
              title: Text(
                friend.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(friend.lastMessage ?? friend.email),
              trailing: IconButton.filledTonal(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
                  );
                  _loadData();
                },
                icon: const Icon(Icons.chat),
                tooltip: 'Nhắn tin',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequests() {
    if (_requests.isEmpty) {
      return const _EmptyState(
        icon: Icons.how_to_reg,
        title: 'Không có lời mời',
        message: 'Các lời mời kết bạn sẽ xuất hiện tại đây.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final request = _requests[index];
        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                MessengerAvatar(name: request.fullName, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        request.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _respond(request, 'REJECT'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Từ chối',
                ),
                IconButton.filled(
                  onPressed: () => _respond(request, 'ACCEPT'),
                  icon: const Icon(Icons.check),
                  tooltip: 'Chấp nhận',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc email',
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
                    ),
            ),
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? const _EmptyState(
                  icon: Icons.manage_search,
                  title: 'Tìm bạn bè',
                  message: 'Nhập tên hoặc email để tìm tài khoản.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        leading: MessengerAvatar(name: user.fullName),
                        title: Text(user.fullName),
                        subtitle: Text(user.email),
                        trailing: _relationshipAction(user),
                      ),
                    );
                  },
                ),
        ),
      ],
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
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
