import 'package:material_ui/material_ui.dart';
import 'package:native_nearby_connections_example/connection_manager.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final manager = ConnectionManager()..addListener(() => setState(() {}));

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ElevatedButton.styleFrom(
      disabledBackgroundColor: Colors.green.withValues(alpha: 0.2),
      disabledForegroundColor: Colors.green.shade800,
    );

    final idle =
        !manager.advertising &&
        !manager.discovering &&
        !manager.startingAdvertising;

    return Scaffold(
      appBar: AppBar(title: Text('Nearby: ${manager.name}')),
      body: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: idle ? manager.advertise : null,
                style: manager.advertising ? active : null,
                child: manager.startingAdvertising
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(manager.advertising ? 'Advertising…' : 'Advertise'),
              ),
              ElevatedButton(
                onPressed: idle ? manager.discover : null,
                style: manager.discovering ? active : null,
                child: Text(manager.discovering ? 'Discovering…' : 'Discover'),
              ),
              ElevatedButton(
                onPressed: manager.connectedIds.isEmpty
                    ? null
                    : manager.sendHello,
                child: const Text('Send hello'),
              ),
              ElevatedButton(
                onPressed: manager.stop,
                child: const Text('Stop'),
              ),
              ElevatedButton(
                onPressed: manager.logLines.isEmpty ? null : manager.clearLog,
                child: const Text('Clear logs'),
              ),
            ],
          ),
          for (final MapEntry(key: id, value: peer) in manager.peers.entries)
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
                  ? () => manager.request(id)
                  : null,
            ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                for (final l in manager.logLines) ListTile(title: Text(l)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
