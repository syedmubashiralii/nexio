import 'package:flutter/material.dart';
import 'package:nexio/nexio.dart';

void main() {
  Nexio.initialize(
    environments: const <String, NexioEnvironment>{
      'demo': NexioEnvironment(baseUrl: 'https://jsonplaceholder.typicode.com'),
      'staging': NexioEnvironment(baseUrl: 'https://staging.example.com'),
    },
    initialEnvironment: 'demo',
    navigatorKey: ChuckerFlutter.navigatorKey,
    loggerEnabled: true,
    enableChucker: true,
    defaultLogInChucker: false,
    retryPolicy: const RetryPolicy(retries: 2),
    cacheConfig: const CacheConfig(defaultTtl: Duration(minutes: 10)),
  );

  runApp(const NexioExampleApp());
}

class NexioExampleApp extends StatelessWidget {
  const NexioExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ChuckerFlutter.navigatorKey,
      title: 'Nexio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006D5B)),
        useMaterial3: true,
      ),
      home: const UsersPage(),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<User> _users = const <User>[];
  String? _error;
  Duration? _duration;
  bool _loading = false;

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Nexio.get<List<User>>(
        '/users',
        cachePolicy: CachePolicy.cacheFirst,
        threadMode: ThreadMode.auto,
        logInChucker: true,
        parser: parseUsers,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _users = response.data;
        _duration = response.metrics.totalDuration;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexio'),
        actions: <Widget>[
          IconButton(
            onPressed: () => Nexio.showLogs(context),
            tooltip: 'Network logs',
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : _users.isEmpty
              ? const Center(child: Text('No users loaded'))
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text('${user.id}')),
                      title: Text(user.name),
                      subtitle: Text(user.email),
                    );
                  },
                ),
      bottomNavigationBar: _duration == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Completed in ${_duration!.inMilliseconds} ms',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _loadUsers,
        icon: _loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_download_outlined),
        label: Text(_loading ? 'Loading' : 'Load users'),
      ),
    );
  }
}

Future<List<User>> parseUsers(Object? input) async {
  final items = input! as List<Object?>;
  return items.cast<Map<String, Object?>>().map(User.fromJson).toList();
}

class User {
  const User({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory User.fromJson(Map<String, Object?> json) {
    return User(
      id: json['id']! as int,
      name: json['name']! as String,
      email: json['email']! as String,
    );
  }
}
