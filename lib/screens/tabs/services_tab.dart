import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/product_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_box.dart';
import '../service_detail_screen.dart';

/// Services directory tab displayed from the root navigation shell.
class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: Consumer<ProductProvider>(
        builder: (context, pp, _) {
          if (pp.isLoading && pp.services.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: const ShimmerCardList(itemCount: 4, itemHeight: 108),
              ),
            );
          }
          if (pp.services.isEmpty) {
            return EmptyState(
              icon: Icons.construction_outlined,
              title: 'No services available',
              message: 'Check back soon for orchard visits and consultations',
              actionLabel: 'Refresh',
              onAction: () => pp.fetchServices(),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pp.services.length,
                itemBuilder: (context, index) {
                  final service = pp.services[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: service.image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AppNetworkImage(
                                  imageUrl:
                                      '${ApiConfig.imageBaseUrl}${service.image}',
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      Icon(Icons.construction, color: primary),
                                ),
                              )
                            : Icon(Icons.construction, color: primary),
                      ),
                      title: Text(
                        service.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            service.description ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatCurrency(service.basePrice)}${service.priceUnit != null ? '/${service.priceUnit}' : ''}',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceDetailScreen(service: service),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
