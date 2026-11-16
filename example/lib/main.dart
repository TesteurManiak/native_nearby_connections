import 'package:material_ui/material_ui.dart';

import 'connection_manager.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _manager = ConnectionManager();

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Active buttons are disabled; tint them so the running mode stands out.
    final active = ElevatedButton.styleFrom(
      disabledBackgroundColor: Colors.green.withValues(alpha: 0.2),
      disabledForegroundColor: Colors.green.shade800,
    );
    return MaterialApp(
      home: ListenableBuilder(
        listenable: _manager,
        builder: (context, _) {
          final m = _manager;
          final idle =
              !m.advertising && !m.discovering && !m.startingAdvertising;
          return Scaffold(
            appBar: AppBar(title: Text('Nearby: ${m.name}')),
            body: Column(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: idle ? m.advertise : null,
                      style: m.advertising ? active : null,
                      child: m.startingAdvertising
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(m.advertising ? 'Advertising…' : 'Advertise'),
                    ),
                    ElevatedButton(
                      onPressed: idle ? m.discover : null,
                      style: m.discovering ? active : null,
                      child: Text(m.discovering ? 'Discovering…' : 'Discover'),
                    ),
                    ElevatedButton(
                      onPressed: m.connectedIds.isEmpty ? null : m.sendHello,
                      child: const Text('Send hello'),
                    ),
                    ElevatedButton(
                      onPressed: m.stop,
                      child: const Text('Stop'),
                    ),
                    ElevatedButton(
                      onPressed: m.logLines.isEmpty ? null : m.clearLog,
                      child: const Text('Clear logs'),
                    ),
                  ],
                ),
                for (final MapEntry(key: id, value: peer) in m.peers.entries)
                  ListTile(
                    title: Text(peer.name),
                    subtitle: Text(peer.state.name),
                    trailing: peer.state == PeerState.connecting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: peer.state == PeerState.found
                        ? () => m.request(id)
                        : null,
                  ),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      for (final l in m.logLines) ListTile(title: Text(l)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
