import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme_config.dart';
import '../../models/service_model.dart';
import '../../providers/product_provider.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_box.dart';
import '../../services/location_service.dart';
import '../my_bookings_screen.dart';
import '../service_detail_screen.dart';

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'per_tree', 'per_kanal', 'featured'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchServices();
      // Prompt GPS & detect district travel every time Services is opened (null-safe in tests)!
      try {
        final loc = Provider.of<LocationService?>(context, listen: false) ?? LocationService.instance;
        loc.promptAndDetectLocation(context, force: true, showGpsDialog: true);
      } catch (_) {}
    });
  }

  void _navigateToService(ServiceModel service) async {
    final loc = Provider.of<LocationService?>(context, listen: false) ?? LocationService.instance;
    if (!loc.hasLocation) {
      await loc.promptAndDetectLocation(context, force: true, showGpsDialog: true);
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(service: service),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ServiceModel> _filterServices(List<ServiceModel> services) {
    return services.where((s) {
      if (_selectedFilter == 'per_tree' && !s.isPerTree) return false;
      if (_selectedFilter == 'per_kanal' && !s.isPerKanal) return false;
      if (_selectedFilter == 'featured' && !s.isFeatured) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = s.name.toLowerCase();
        final desc = (s.description ?? '').toLowerCase();
        final shortDesc = (s.shortDescription ?? '').toLowerCase();
        final cat = (s.categoryName ?? '').toLowerCase();
        final unit = (s.unitDisplay).toLowerCase();
        return name.contains(q) ||
            desc.contains(q) ||
            shortDesc.contains(q) ||
            cat.contains(q) ||
            unit.contains(q);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Orchard Services',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'My Bookings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => context.read<ProductProvider>().fetchServices(),
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, pp, _) {
          if (pp.servicesLoading && pp.services.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: const ShimmerCardList(itemCount: 4, itemHeight: 140),
              ),
            );
          }

          if (pp.services.isEmpty) {
            return EmptyState(
              icon: Icons.agriculture_outlined,
              title: 'No services available',
              message:
                  'Check back soon for seasonal orchard visits, spraying, and consultations.',
              actionLabel: 'Refresh',
              onAction: () => pp.fetchServices(),
            );
          }

          final filteredServices = _filterServices(pp.services);

          return RefreshIndicator(
            onRefresh: () => pp.fetchServices(),
            color: primary,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // GPS Location & District Travel Banner
                    _buildLocationDetectionBar(primary),
                    const SizedBox(height: 10),

                    // 1. Search Box
                    _buildSearchBar(),

                    const SizedBox(height: 10),

                    // 3. Filter Chips
                    _buildFilterChips(primary, pp.services.length),

                    const SizedBox(height: 14),

                    // 4. Services List or Empty Search
                    if (filteredServices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No matching services found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Try adjusting your search terms or filter selection.',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _selectedFilter = 'all';
                                });
                              },
                              icon: const Icon(Icons.clear_all_rounded, size: 18),
                              label: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredServices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final service = filteredServices[index];
                          return _buildServiceCard(context, service, primary);
                        },
                      ),

                    const SizedBox(height: 16),

                    // 5. Help & Custom Scope Banner
                    _buildHelpBanner(primary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationDetectionBar(Color primary) {
    LocationService? loc;
    try {
      loc = Provider.of<LocationService?>(context);
    } catch (_) {
      loc = null;
    }
    if (loc == null) return const SizedBox.shrink();
    final activeLoc = loc;

    return AnimatedBuilder(
      animation: activeLoc,
      builder: (context, _) {
        if (activeLoc.isLocating) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB45309)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Detecting orchard GPS location & calculating travel...',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (activeLoc.hasLocation) {
          final zone = activeLoc.districtZoneName != null ? ' • ${activeLoc.districtZoneName}' : '';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Orchard: ${activeLoc.address ?? "GPS detected"}$zone',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15803D),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => activeLoc.promptAndDetectLocation(context, force: true),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(Icons.near_me_outlined, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Set orchard location to auto-calculate district travel rates',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => activeLoc.promptAndDetectLocation(context, force: true),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: const Text('Turn On GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search services (e.g. pruning, spraying, soil)...',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, size: 21, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel_rounded, size: 18, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFilterChips(Color primary, int totalCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _filterChipItem('All ($totalCount)', 'all', primary),
          const SizedBox(width: 8),
          _filterChipItem(
              'Per Tree', 'per_tree', primary, icon: Icons.nature_rounded),
          const SizedBox(width: 8),
          _filterChipItem(
              'Per Kanal', 'per_kanal', primary, icon: Icons.crop_free_rounded),
          const SizedBox(width: 8),
          _filterChipItem(
              'Featured', 'featured', primary, icon: Icons.star_outline_rounded),
        ],
      ),
    );
  }

  Widget _filterChipItem(String label, String id, Color primary,
      {IconData? icon}) {
    final isSelected = _selectedFilter == id;
    return ChoiceChip(
      showCheckmark: false,
      avatar: icon != null
          ? Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            )
          : null,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      selected: isSelected,
      selectedColor: primary,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      onSelected: (_) => setState(() => _selectedFilter = id),
    );
  }

  Widget _buildServiceCard(
      BuildContext context, ServiceModel service, Color primary) {
    final visuals = _getServiceVisuals(service, primary);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _navigateToService(service),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: Icon + Name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distinct Service Visual Icon / Thumbnail
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: visuals.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: visuals.fg.withValues(alpha: 0.12),
                        ),
                      ),
                      child: service.image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: AppNetworkImage(
                                imageUrl:
                                    ApiConfig.resolveImageUrl(service.image),
                                fit: BoxFit.cover,
                                errorWidget: (errContext, errUrl, err) => Icon(
                                  visuals.icon,
                                  color: visuals.fg,
                                  size: 26,
                                ),
                              ),
                            )
                          : Icon(visuals.icon, color: visuals.fg, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          if (service.categoryName != null &&
                              service.categoryName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              service.categoryName!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Description
                Text(
                  service.shortDescription ?? service.description ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 14),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
                const SizedBox(height: 12),

                // Bottom Action Bar: Formatted Price + Book Service Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Service Rate',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            service.formattedPrice,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: primary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _navigateToService(service),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Book Service'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpBanner(Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.headset_mic_outlined, color: primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need Large Orchard Coverage?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'For contracts exceeding 20 Kanals or custom seasonal packages, contact our field specialists.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ServiceVisuals _getServiceVisuals(ServiceModel service, Color primary) {
    final name = service.name.toLowerCase();
    final slug = service.slug.toLowerCase();

    if (name.contains('prun') || slug.contains('prun')) {
      return const _ServiceVisuals(
        icon: Icons.content_cut_rounded,
        bg: Color(0xFFE8F5E9),
        fg: Color(0xFF2E7D32),
      );
    }
    if (name.contains('spray') || slug.contains('spray')) {
      return const _ServiceVisuals(
        icon: Icons.water_drop_rounded,
        bg: Color(0xFFE0F7FA),
        fg: Color(0xFF00838F),
      );
    }
    if (name.contains('soil') ||
        name.contains('analy') ||
        slug.contains('soil')) {
      return const _ServiceVisuals(
        icon: Icons.science_rounded,
        bg: Color(0xFFEDE7F6),
        fg: Color(0xFF5E35B1),
      );
    }
    if (name.contains('pest') || slug.contains('pest')) {
      return const _ServiceVisuals(
        icon: Icons.shield_outlined,
        bg: Color(0xFFFFF3E0),
        fg: Color(0xFFE65100),
      );
    }
    if (name.contains('visit') ||
        name.contains('consult') ||
        slug.contains('consult')) {
      return const _ServiceVisuals(
        icon: Icons.support_agent_rounded,
        bg: Color(0xFFE3F2FD),
        fg: Color(0xFF1565C0),
      );
    }

    return _ServiceVisuals(
      icon: Icons.eco_rounded,
      bg: primary.withValues(alpha: 0.12),
      fg: primary,
    );
  }
}

class _ServiceVisuals {
  final IconData icon;
  final Color bg;
  final Color fg;

  const _ServiceVisuals({
    required this.icon,
    required this.bg,
    required this.fg,
  });
}
