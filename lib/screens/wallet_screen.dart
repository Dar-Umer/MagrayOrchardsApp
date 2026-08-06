import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../models/wallet.dart';
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
      context.read<WalletProvider>().fetchBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBalanceCard(wallet, cs),
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
    );
  }

  Widget _buildBalanceCard(WalletProvider wallet, ColorScheme cs) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Text(
              'Available Balance',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            wallet.isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    '₹${wallet.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ],
        ),
      ),
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
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }

    if (wallet.errorMessage != null && wallet.transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(wallet.errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => wallet.fetchTransactions(type: _filterType),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (wallet.transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('No transactions yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
              SizedBox(height: 8),
              Text('Add money to your wallet to get started', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: wallet.transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
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
              '${tx.createdAt!.day}/${tx.createdAt!.month}/${tx.createdAt!.year} ${tx.createdAt!.hour.toString().padLeft(2, '0')}:${tx.createdAt!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            )
          : null,
      trailing: Text(
        '$prefix₹${tx.amount.toStringAsFixed(0)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 15,
        ),
      ),
    );
  }
}
