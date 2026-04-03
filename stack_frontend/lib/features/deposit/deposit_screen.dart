import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/auth_service.dart';
import '../../core/api_service.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _invoice;
  List<dynamic> _depositHistory = [];
  int _selectedStep = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userId == null) return;
    final response = await apiService.get(
      '/deposit/history/${authService.userId}',
    );
    if (response['success'] == true && mounted) {
      setState(() => _depositHistory = response['deposits'] ?? []);
    }
  }

  Future<void> _createDeposit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 10) {
      setState(() => _error = 'Minimum deposit is \$10 USDT');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _invoice = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final response = await apiService.post('/deposit/create', {
      'user_id': authService.userId,
      'amount': amount,
    });

    setState(() => _isLoading = false);

    if (response['success'] == true) {
      setState(() => _invoice = response['invoice']);
      await _loadHistory();
    } else {
      setState(() => _error = response['error'] ?? 'Failed to create deposit');
    }
  }

  Future<void> _openInvoice() async {
    if (_invoice == null || _invoice!['invoice_url'] == null) return;
    final url = Uri.parse(_invoice!['invoice_url']);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundSecondary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.neonGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonGreen.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'DEPOSIT',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.neonGreen,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildSteps(),
            const SizedBox(height: 24),
            if (_invoice == null) ...[
              _buildDepositForm(),
            ] else ...[
              _buildInvoiceCard(),
            ],
            const SizedBox(height: 32),
            _buildHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.neonGreen.withValues(alpha: 0.1),
            AppColors.backgroundSecondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.security_rounded,
                color: AppColors.neonGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'SECURE DEPOSITS',
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonGreen,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Minimum Deposit', '\$10.00 USDT'),
          _infoRow('Currency', 'USDT (TRC20)'),
          _infoRow('Network', 'Tron (TRC20)'),
          _infoRow('Confirmation', 'Instant via NOWPayments'),
          const SizedBox(height: 8),
          Text(
            'Your deposit is processed securely through NOWPayments. Funds are added to your balance automatically after confirmation.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    final steps = [
      {
        'icon': Icons.input_rounded,
        'title': 'Enter Amount',
        'desc': 'Min \$10',
      },
      {
        'icon': Icons.account_balance_wallet,
        'title': 'Get Address',
        'desc': 'TRC20 wallet',
      },
      {
        'icon': Icons.send_rounded,
        'title': 'Send USDT',
        'desc': 'From your wallet',
      },
      {
        'icon': Icons.check_circle,
        'title': 'Auto Credit',
        'desc': 'Instant balance',
      },
    ];

    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final isActive = _selectedStep >= i;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.neonGreen.withValues(alpha: 0.15)
                      : AppColors.backgroundTertiary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? AppColors.neonGreen.withValues(alpha: 0.4)
                        : AppColors.backgroundTertiary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  step['icon'] as IconData,
                  color: isActive ? AppColors.neonGreen : AppColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step['title'] as String,
                textAlign: TextAlign.center,
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                step['desc'] as String,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDepositForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.backgroundTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEPOSIT AMOUNT',
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.orbitron(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.neonGreen,
            ),
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: GoogleFonts.orbitron(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.neonGreen,
              ),
              suffixText: 'USDT',
              suffixStyle: GoogleFonts.rajdhani(
                fontSize: 16,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.backgroundTertiary.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: '0.00',
              hintStyle: GoogleFonts.orbitron(
                fontSize: 28,
                color: AppColors.textMuted.withValues(alpha: 0.3),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.inter(color: AppColors.neonRed, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createDeposit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonGreen,
                foregroundColor: AppColors.backgroundPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.backgroundPrimary,
                      ),
                    )
                  : Text(
                      'GENERATE DEPOSIT ADDRESS',
                      style: GoogleFonts.rajdhani(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  color: AppColors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEPOSIT ADDRESS GENERATED',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.amber,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '\$${_invoice!['amount']} USDT',
                      style: GoogleFonts.orbitron(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Send exactly this amount to:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _invoice!['payment_address'] ?? '',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    color: AppColors.cyan,
                    wordSpacing: 0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Network: ${_invoice!['pay_currency']}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openInvoice,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                'OPEN PAYMENT PAGE',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.backgroundPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your balance will be updated automatically after payment confirmation',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_depositHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.textMuted.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No deposits yet',
                style: GoogleFonts.inter(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DEPOSIT HISTORY',
          style: GoogleFonts.rajdhani(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        ..._depositHistory.map((deposit) => _depositRow(deposit)).toList(),
      ],
    );
  }

  Widget _depositRow(Map<String, dynamic> deposit) {
    final status = deposit['payment_status'] ?? 'waiting';
    final statusColor = status == 'finished'
        ? AppColors.neonGreen
        : status == 'confirming'
        ? AppColors.amber
        : AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.backgroundTertiary),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${deposit['amount_usdt']} USDT',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _formatDate(deposit['created_at']),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.rajdhani(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
