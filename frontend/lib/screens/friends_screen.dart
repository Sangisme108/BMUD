import 'package:flutter/material.dart';

import '../models/social_models.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _socialService = SocialService();
  final _searchController = TextEditingController();

  List<FriendUser> _conversations = [];
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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _socialService.getConversations(),
        _socialService.getFriendRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _conversations = results[0] as List<FriendUser>;
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
          title: const Text('Bạn bè và tin nhắn'),
          actions: [
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Trò chuyện'),
              Tab(icon: Icon(Icons.person_add_alt), text: 'Lời mời'),
              Tab(icon: Icon(Icons.search), text: 'Tìm người'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _loadData)
            : TabBarView(
                children: [
                  _buildConversations(),
                  _buildRequests(),
                  _buildSearch(),
                ],
              ),
      ),
    );
  }

  Widget _buildConversations() {
    if (_conversations.isEmpty) {
      return const Center(
        child: Text('Chưa có bạn bè. Hãy tìm và gửi lời mời kết bạn.'),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final friend = _conversations[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(
                friend.fullName.isEmpty
                    ? '?'
                    : friend.fullName.substring(0, 1).toUpperCase(),
              ),
            ),
            title: Text(friend.fullName),
            subtitle: Text(
              friend.lastMessage ?? friend.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: friend.unreadCount > 0
                ? CircleAvatar(
                    radius: 13,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      friend.unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
              );
              _loadData();
            },
          );
        },
      ),
    );
  }

  Widget _buildRequests() {
    if (_requests.isEmpty) {
      return const Center(child: Text('Không có lời mời kết bạn'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(request.email),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _respond(request, 'REJECT'),
                      child: const Text('Từ chối'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _respond(request, 'ACCEPT'),
                      child: const Text('Chấp nhận'),
                    ),
                  ],
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
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Tên hoặc email',
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
                      icon: const Icon(Icons.search),
                    ),
            ),
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? const Center(
                  child: Text('Nhập tên hoặc email để tìm tài khoản'),
                )
              : ListView.separated(
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      title: Text(user.fullName),
                      subtitle: Text(user.email),
                      trailing: _relationshipAction(user),
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
      _ => FilledButton.tonal(
        onPressed: () => _sendRequest(user),
        child: const Text('Kết bạn'),
      ),
    };
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
