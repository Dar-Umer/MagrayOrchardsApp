import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/wallet_debit_card.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../models/wallet.dart';
import '../services/shop_config.dart';
import '../utils/formatters.dart';
import 'wallet_topup_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String? _filterType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = context.read<WalletProvider>();
      wallet.fetchBalance();
      wallet.fetchTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await wallet.fetchBalance();
          await wallet.fetchTransactions(type: _filterType);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildBalanceCard(wallet, auth, cs),
                const SizedBox(height: 20),
                _buildTopUpButton(cs),
                const SizedBox(height: 24),
                _buildTransactionHeader(cs),
                const SizedBox(height: 8),
                _buildFilterChips(cs),
                const SizedBox(height: 8),
                _buildTransactionList(wallet, cs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    WalletProvider wallet,
    AuthProvider auth,
    ColorScheme cs,
  ) {
    final user = auth.user;
    return WalletDebitCard(
      balance: wallet.balance,
      cardHolderName: user?.displayName ?? 'Valued Member',
      brandName: ShopConfig.siteName,
      userId: user?.id ?? 0,
      isProMember: user?.isProMember ?? false,
      isLoading: wallet.isLoading,
      primaryColor: cs.primary,
    );
  }

  Widget _buildTopUpButton(ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WalletTopUpScreen()),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Money', style: TextStyle(color: Colors.white, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildTransactionHeader(ColorScheme cs) {
    return Text(
      'Transactions',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: cs.primary,
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme cs) {
    return Row(
      children: [
        _filterChip('All', null),
        const SizedBox(width: 8),
        _filterChip('Credit', 'credit'),
        const SizedBox(width: 8),
        _filterChip('Debit', 'debit'),
        const SizedBox(width: 8),
        _filterChip('Refund', 'refund'),
      ],
    );
  }

  Widget _filterChip(String label, String? type) {
    final isSelected = _filterType == type;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterType = selected ? type : null);
        context.read<WalletProvider>().fetchTransactions(type: _filterType);
      },
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
    );
  }

  Widget _buildTransactionList(WalletProvider wallet, ColorScheme cs) {
    if (wallet.isLoading && wallet.transactions.isEmpty) {
      return const SizedBox(
        height: 280,
        child: ShimmerCardList(itemCount: 3, itemHeight: 72),
      );
    }

    if (wallet.errorMessage != null && wallet.transactions.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load transactions',
        message: wallet.errorMessage,
        actionLabel: 'Try Again',
        onAction: () => wallet.fetchTransactions(type: _filterType),
      );
    }

    if (wallet.transactions.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long,
        title: 'No transactions yet',
        message: 'Add money to your wallet to get started',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: wallet.transactions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tx = wallet.transactions[index];
        return _buildTransactionTile(tx, cs);
      },
    );
  }

  Widget _buildTransactionTile(WalletTransaction tx, ColorScheme cs) {
    final isCredit = tx.isCredit || tx.isRefund;
    final color = isCredit ? Colors.green : Colors.red;
    final icon = tx.isRefund
        ? Icons.replay
        : tx.isCredit
            ? Icons.arrow_downward
            : Icons.arrow_upward;
    final prefix = tx.isRefund ? '+' : (isCredit ? '+' : '-');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        tx.description,
        style: const TextStyle(fontSize: 14),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: tx.createdAt != null
          ? Text(
              formatDateTime(tx.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            )
          : null,
      trailing: Text(
        '$prefix${formatCurrency(tx.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 15,
        ),
      ),
    );
  }
}
