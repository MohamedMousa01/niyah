import 'package:flutter/material.dart';

import '../data/catalog_repository.dart';
import '../l10n/app_localizations.dart';
import '../state/app_scope.dart';
import '../theme/niyah_theme.dart';
import 'widgets.dart';

const _topicIcons = <String, IconData>{
  'restaurant': Icons.restaurant,
  'work': Icons.work_outline,
  'book': Icons.menu_book_outlined,
  'prayer': Icons.self_improvement,
  'bedtime': Icons.bedtime_outlined,
  'flight': Icons.flight_takeoff,
  'family': Icons.family_restroom,
  'sport': Icons.directions_run,
  'shopping': Icons.shopping_bag_outlined,
  'groups': Icons.groups_outlined,
};

/// "Sto per…": griglia di momenti della giornata (architettura §2.2).
class StoPerPage extends StatelessWidget {
  const StoPerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navStoPer)),
      body: FutureBuilder<List<TopicItem>>(
        key: ValueKey(c.settings.language),
        future: c.catalog.topics(c.settings.language),
        builder: (context, snap) {
          final topics = snap.data;
          if (topics == null) {
            return snap.hasError ? EmptyState(text: l.genericError, icon: Icons.error_outline) : const SizedBox.shrink();
          }
          return LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 900 ? 4 : (box.maxWidth >= 600 ? 3 : 2);
              return GridView.count(
                padding: const EdgeInsets.all(NiyahSpace.m),
                crossAxisCount: columns,
                mainAxisSpacing: NiyahSpace.m,
                crossAxisSpacing: NiyahSpace.m,
                childAspectRatio: 1.3,
                children: [for (final t in topics) _TopicCard(topic: t)],
              );
            },
          );
        },
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final TopicItem topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TopicPage(topic: topic))),
        child: Padding(
          padding: const EdgeInsets.all(NiyahSpace.m),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_topicIcons[topic.icon] ?? Icons.circle_outlined, size: 32, color: theme.colorScheme.primary),
              const SizedBox(height: NiyahSpace.s),
              Text(topic.name, textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenuti verificati collegati a un momento. Finché il pannello admin non
/// ne pubblica, la pagina lo dice con calma invece di mostrare un vuoto.
class TopicPage extends StatelessWidget {
  const TopicPage({super.key, required this.topic});

  final TopicItem topic;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(topic.name)),
      body: NiyahPage(
        children: [
          // I contenuti (pager precedente/successivo) arrivano con il primo
          // lotto di versetti e hadith verificati.
          EmptyState(text: l.stoPerEmpty, icon: _topicIcons[topic.icon] ?? Icons.circle_outlined),
        ],
      ),
    );
  }
}
