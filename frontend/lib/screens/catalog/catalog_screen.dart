import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/responsive.dart';
import '../../models/catalog.dart';
import '../../providers/catalog_provider.dart';
import '../../services/product_service.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';

/// Product listing with category, brand and specification filtering.
///
/// Every filter maps onto a query parameter the backend's `ProductFilter`
/// understands, so the server does the filtering, sorting and paging. The
/// sidebar's facet list comes from `Category.filters`, the admin-authored
/// JSONField whose keys are matched against `Product.specification`.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    this.categorySlug,
    this.brandSlug,
    this.search,
    this.featured = false,
  });

  final String? categorySlug;
  final String? brandSlug;
  final String? search;
  final bool featured;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final ProductListProvider _list;

  @override
  void initState() {
    super.initState();
    _list = ProductListProvider(context.read<ProductService>());
    // Not awaited: the screen renders the provider's own loading state.
    unawaited(_list.applyQuery(_queryFromWidget()));
  }

  @override
  void didUpdateWidget(CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell routes category/search changes through the URL, so re-apply
    // when any of them change.
    if (oldWidget.categorySlug != widget.categorySlug ||
        oldWidget.brandSlug != widget.brandSlug ||
        oldWidget.search != widget.search ||
        oldWidget.featured != widget.featured) {
      unawaited(_list.applyQuery(_queryFromWidget()));
    }
  }

  ProductQuery _queryFromWidget() => ProductQuery(
    categorySlug: widget.categorySlug,
    brandSlug: widget.brandSlug,
    search: widget.search,
    featuredOnly: widget.featured,
    sort: _list.query.sort,
    pageSize: _list.query.pageSize,
  );

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.read<CatalogProvider>();

    return ChangeNotifierProvider.value(
      value: _list,
      child: AutoRefresh(
        onRefresh: () {
          _list.refreshSilently();
          catalogProvider.load(force: true, silent: true);
        },
        child: const _CatalogBody(),
      ),
    );
  }
}

/// Desktop filter sidebar geometry. The grid needs to know how much of the
/// content width the sidebar takes, so the layout and that calculation read
/// the same constants rather than repeating the numbers.
const double _sidebarWidth = 264;
const double _sidebarGap = 26;
const double _sidebarSpan = _sidebarWidth + _sidebarGap;

class _CatalogBody extends StatelessWidget {
  const _CatalogBody();

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ProductListProvider>();
    final catalog = context.watch<CatalogProvider>();
    final isDesktop = Responsive.isDesktop(context);

    final activeCategory = catalog.categoryBySlug(list.query.categorySlug);

    final filters = _FilterPanel(category: activeCategory);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CatalogHeader(category: activeCategory),
          const SizedBox(height: 18),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: _sidebarWidth, child: filters),
                const SizedBox(width: _sidebarGap),
                Expanded(child: _ResultsArea(hasSidebar: true)),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MobileFilterBar(category: activeCategory),
                const SizedBox(height: 14),
                _ResultsArea(hasSidebar: false),
              ],
            ),
        ],
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({this.category});

  final Category? category;

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ProductListProvider>();
    final theme = Theme.of(context);
    final query = list.query;

    final title = switch (true) {
      _ when (query.search ?? '').isNotEmpty => 'Results for "${query.search}"',
      _ when query.featuredOnly => 'Featured products',
      _ when category != null => category!.name,
      _ => 'All products',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          list.isLoading
              ? 'Searching…'
              : '${list.totalCount} ${list.totalCount == 1 ? 'product' : 'products'} found',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if ((category?.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            category!.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Sort + page-size controls and the product grid.
class _ResultsArea extends StatelessWidget {
  const _ResultsArea({required this.hasSidebar});

  final bool hasSidebar;

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ProductListProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: const [
            // Keyed so a background refresh re-uses these elements instead
            // of building new ones underneath an open dropdown menu.
            _SortDropdown(key: ValueKey('sort')),
            _PageSizeDropdown(key: ValueKey('page-size')),
          ],
        ),
        const SizedBox(height: 16),
        if (list.isLoading)
          const LoadingState(message: 'Loading products…')
        else if (list.error != null)
          ErrorState(message: list.error!, onRetry: list.refresh)
        else if (list.products.isEmpty)
          EmptyState(
            title: 'No products matched',
            message: list.query.hasFilters
                ? 'Try removing a filter or searching for something else.'
                : 'There are no published products yet.',
            icon: Icons.search_off_rounded,
            action: list.query.hasFilters
                ? OutlinedButton.icon(
                    onPressed: list.clearFilters,
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear filters'),
                  )
                : null,
          )
        else ...[
          ProductGrid(
            products: list.products,
            columns: Responsive.gridColumns(context, hasSidebar: hasSidebar),
            // The sidebar and its gap come out of the page's content width.
            availableWidth: hasSidebar
                ? Responsive.contentWidth(context) - _sidebarSpan
                : null,
          ),
          if (list.hasMore) ...[
            const SizedBox(height: 24),
            Center(
              child: OutlinedButton.icon(
                onPressed: list.isLoadingMore ? null : list.loadMore,
                icon: list.isLoadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  list.isLoadingMore
                      ? 'Loading…'
                      : 'Load more (${list.products.length} of ${list.totalCount})',
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ProductListProvider>();

    return SizedBox(
      width: 230,
      child: DropdownButtonFormField<ProductSort>(
        initialValue: list.query.sort,
        isDense: true,
        // Without isExpanded the button sizes itself to its longest label and
        // overflows the SizedBox instead of ellipsising inside it.
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Sort by',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          for (final sort in ProductSort.values)
            DropdownMenuItem(value: sort, child: Text(sort.label)),
        ],
        onChanged: (sort) {
          if (sort != null) list.setSort(sort);
        },
      ),
    );
  }
}

/// Page size, capped at the backend's `max_page_size` of 90.
class _PageSizeDropdown extends StatelessWidget {
  const _PageSizeDropdown({super.key});

  static const _options = [12, 20, 48, AppConfig.maxPageSize];

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ProductListProvider>();

    return SizedBox(
      width: 130,
      child: DropdownButtonFormField<int>(
        initialValue: _options.contains(list.query.pageSize)
            ? list.query.pageSize
            : AppConfig.defaultPageSize,
        isDense: true,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Per page',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          for (final size in _options)
            DropdownMenuItem(value: size, child: Text('$size')),
        ],
        onChanged: (size) {
          if (size != null) list.setPageSize(size);
        },
      ),
    );
  }
}

/// Desktop sidebar: sub-categories, brands and specification facets.
class _FilterPanel extends StatelessWidget {
  const _FilterPanel({this.category});

  final Category? category;

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ProductListProvider>();
    final catalog = context.watch<CatalogProvider>();
    final theme = Theme.of(context);

    // Brands scoped to the active category when there is one, else all brands.
    final brands = category != null && category!.brands.isNotEmpty
        ? category!.brands
        : catalog.brands;

    final facets = category?.facets ?? const <String, List<String>>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Filters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (list.query.hasFilters)
              TextButton(
                onPressed: list.clearFilters,
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (category?.hasChildren ?? false)
          _FilterGroup(
            title: category!.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in category!.subCategories)
                  _CheckRow(
                    label: child.name,
                    selected: list.query.categorySlug == child.slug,
                    onChanged: (selected) => list.setCategory(
                      selected ? child.slug : category!.slug,
                    ),
                  ),
              ],
            ),
          ),
        if (brands.isNotEmpty)
          _FilterGroup(
            title: 'Brand',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final brand in brands)
                  _CheckRow(
                    label: brand.name,
                    selected: list.query.brandSlug == brand.slug,
                    onChanged: (selected) =>
                        list.setBrand(selected ? brand.slug : null),
                  ),
              ],
            ),
          ),
        // Specification facets, from the category's own `filters` JSONField.
        for (final facet in facets.entries)
          _FilterGroup(
            title: facet.key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final value in facet.value)
                  _CheckRow(
                    label: value,
                    selected: list.isSpecSelected(facet.key, value),
                    onChanged: (_) => list.toggleSpecFilter(facet.key, value),
                  ),
              ],
            ),
          ),
        if (facets.isEmpty &&
            brands.isEmpty &&
            !(category?.hasChildren ?? false))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              category == null
                  ? 'Pick a category to see its filters.'
                  : 'This category has no filters configured.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            title: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            children: [child],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                onChanged: (value) => onChanged(value ?? false),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mobile/tablet: filters move into a bottom sheet.
class _MobileFilterBar extends StatelessWidget {
  const _MobileFilterBar({this.category});

  final Category? category;

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ProductListProvider>();
    final activeCount =
        list.query.specFilters.values.fold<int>(
          0,
          (sum, values) => sum + values.length,
        ) +
        ((list.query.brandSlug ?? '').isEmpty ? 0 : 1);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (sheetContext) => ChangeNotifierProvider.value(
                value: list,
                child: DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.8,
                  maxChildSize: 0.95,
                  builder: (context, controller) => SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: _FilterPanel(category: category),
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(
              activeCount == 0 ? 'Filters' : 'Filters ($activeCount)',
            ),
          ),
        ),
      ],
    );
  }
}
