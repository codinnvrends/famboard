import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/text.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../../domain/views.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';

/// Full-text search over titles, notes and category names (spec FR-31).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final entries = session == null
        ? const <Entry>[]
        : ref.watch(allEntriesProvider(session.familyId)).value ?? const <Entry>[];
    final q = normalizeText(_query);
    final results = q.isEmpty
        ? const <Entry>[]
        : (entries.where((e) {
            if (e.deleted) return false;
            final cat = categoryById(e.categoryId);
            final hay = normalizeText('${e.title} ${e.note ?? ''} ${cat.en} ${cat.hi}');
            return q.split(' ').every(hay.contains);
          }).toList()
          ..sort((a, b) {
            if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
            return compareEntries(a, b);
          }));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: l.searchHint,
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: q.isEmpty
          ? const SizedBox.shrink()
          : results.isEmpty
              ? EmptyState(icon: Icons.search_off, title: l.noResults)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => EntryTile(results[i]),
                ),
    );
  }
}
