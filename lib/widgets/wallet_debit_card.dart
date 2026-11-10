import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/formatters.dart';

/// Displays the customer's wallet balance styled as a physical debit/prepaid card.
class WalletDebitCard extends StatefulWidget {
  final double balance;
  final String cardHolderName;
  final String brandName;
  final int userId;
  final bool isProMember;
  final bool isLoading;
  final Color primaryColor;

  const WalletDebitCard({
    super.key,
    required this.balance,
    required this.cardHolderName,
    required this.brandName,
    required this.userId,
    required this.isProMember,
    required this.isLoading,
    required this.primaryColor,
  });

  @override
  State<WalletDebitCard> createState() => _WalletDebitCardState();
}

class _WalletDebitCardState extends State<WalletDebitCard> {
  bool _hideBalance = false;

  String get _maskedCardNumber {
    final suffix = widget.userId > 0
        ? (1000 + (widget.userId % 9000)).toString().padLeft(4, '0')
        : '0001';
    return '6078  ••••  ••••  $suffix';
  }

  @override
  Widget build(BuildContext context) {
    // Anchor gradient stops in deep obsidian tones so white typography keeps >7:1 contrast across palettes.
    final deepStart = Color.lerp(const Color(0xFF091114), widget.primaryColor, 0.28)!;
    final deepMid = Color.lerp(const Color(0xFF0F2024), widget.primaryColor, 0.56)!;
    final richEnd = Color.lerp(const Color(0xFF081417), widget.primaryColor, 0.82)!;

    final displayBrand = (widget.brandName.trim().isNotEmpty
            ? widget.brandName.trim()
            : 'Magray Orchards')
        .toUpperCase();
    final displayHolder = (widget.cardHolderName.trim().isNotEmpty
            ? widget.cardHolderName.trim()
            : 'Valued Member')
        .toUpperCase();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minHeight: 214),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [deepStart, deepMid, richEnd],
                        stops: const [0.0, 0.52, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _CardPatternPainter(),
                    ),
                  ),
                ),
                // Specular card edge highlight
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderRow(displayBrand),
                      const SizedBox(height: 14),
                      _buildChipAndBalanceRow(),
                      const SizedBox(height: 14),
                      Text(
                        _maskedCardNumber,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildFooterRow(displayHolder),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(String displayBrand) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: Color(0xFFF6D365),
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayBrand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'PREPAID WALLET',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: const Text(
            'INSTANT PAY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ExcludeSemantics(
          child: Transform.rotate(
            angle: math.pi / 2,
            child: Icon(
              Icons.wifi_rounded,
              color: Colors.white.withValues(alpha: 0.78),
              size: 19,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChipAndBalanceRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 44,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF7E199),
                  Color(0xFFD7A93D),
                  Color(0xFF9F741D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFFFFF0B8).withValues(alpha: 0.65),
                width: 0.8,
              ),
            ),
            child: CustomPaint(
              painter: _EmvChipPainter(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AVAILABLE BALANCE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              if (widget.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else
                Text(
                  _hideBalance
                      ? 'Rs. •••••'
                      : formatCurrency(widget.balance, alwaysShowDecimals: true),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            tooltip: _hideBalance ? 'Show balance' : 'Hide balance',
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
            icon: Icon(
              _hideBalance
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.white.withValues(alpha: 0.78),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterRow(String displayHolder) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CARD HOLDER',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayHolder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'STATUS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.isProMember ? 'PRO ACTIVE' : 'ACTIVE',
              style: TextStyle(
                color: widget.isProMember
                    ? const Color(0xFFF6D365)
                    : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 22,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEB001B).withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF79E1B).withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'WALLET',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmvChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF6B4E10).withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Horizontal pad dividers
    canvas.drawLine(Offset(0, h * 0.34), Offset(w * 0.34, h * 0.34), linePaint);
    canvas.drawLine(Offset(0, h * 0.66), Offset(w * 0.34, h * 0.66), linePaint);
    canvas.drawLine(Offset(w * 0.66, h * 0.34), Offset(w, h * 0.34), linePaint);
    canvas.drawLine(Offset(w * 0.66, h * 0.66), Offset(w, h * 0.66), linePaint);

    // Center contact box
    final centerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.2, w * 0.32, h * 0.6),
      const Radius.circular(3),
    );
    canvas.drawRRect(centerRect, linePaint);

    // Vertical contact extensions
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h * 0.2), linePaint);
    canvas.drawLine(Offset(w * 0.5, h * 0.8), Offset(w * 0.5, h), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final origin = Offset(size.width * 0.92, size.height * 0.14);
    for (final radius in [54.0, 96.0, 142.0, 190.0]) {
      canvas.drawCircle(origin, radius, ringPaint);
    }

    final sheenPath = Path()
      ..moveTo(size.width * 0.18, 0)
      ..lineTo(size.width * 0.44, 0)
      ..lineTo(size.width * 0.2, size.height)
      ..lineTo(-size.width * 0.06, size.height)
      ..close();

    canvas.drawPath(
      sheenPath,
      Paint()..color = Colors.white.withValues(alpha: 0.045),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
