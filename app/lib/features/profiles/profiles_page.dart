import 'package:flutter/material.dart';

/// Profiles - 节点列表
class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Node',
            onPressed: () {},
          ),
        ],
      ),
      body: _buildMockList(theme),
    );
  }

  Widget _buildMockList(ThemeData theme) {
    final mockNodes = [
      ('HK-01 | Azure', 'VLESS', '42 ms'),
      ('JP-02 | AWS', 'Trojan', '68 ms'),
      ('US-03 | GCP', 'VMess', '120 ms'),
      ('SG-04 | DO', 'Shadowsocks', '55 ms'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockNodes.length,
      itemBuilder: (context, index) {
        final (name, type, delay) = mockNodes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: Text(
                type[0],
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
            title: Text(name),
            subtitle: Text(type),
            trailing: Text(
              delay,
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {},
          ),
        );
      },
    );
  }
}
