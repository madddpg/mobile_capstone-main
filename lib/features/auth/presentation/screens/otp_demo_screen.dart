import 'package:flutter/material.dart';
import 'package:iconstruct/features/auth/data/email_service.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

class OtpDemoScreen extends StatefulWidget {
  const OtpDemoScreen({super.key});

  @override
  State<OtpDemoScreen> createState() => _OtpDemoScreenState();
}

class _OtpDemoScreenState extends State<OtpDemoScreen> {
  final EmailService _emailService = EmailService();

  bool _loading = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _loading = true);

    try {
      final result = await _emailService.sendCurrentUserOtp();

      if (!mounted) return;
      showAppMessage(
        context,
        SnackBar(content: Text(result.message)),
        kind: AppMessageKind.success,
      );
    } on EmailApiException catch (e) {
      if (!mounted) return;
      showAppMessage(context, SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      showAppMessage(context, const SnackBar(content: Text('Something went wrong.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send OTP (Demo)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This demo sends a 6-digit OTP to the currently signed-in user.',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _sendOtp,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
