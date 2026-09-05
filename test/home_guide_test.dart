import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/onboarding/data/home_guide_steps.dart';

void main() {
  group('homeGuideSteps', () {
    test('walks estimate → quotations → compare → chat', () {
      final steps = homeGuideSteps(firstName: 'Ahmad');

      expect(steps, hasLength(5));
      expect(steps.first.target, HomeGuideTarget.welcome);
      expect(steps.first.title, 'Welcome, Ahmad.');
      expect(steps.last.target, HomeGuideTarget.shopChat);
      expect(steps.last.nextLabel, 'Got it');

      final joined = steps.map((s) => '${s.title} ${s.body}').join(' ').toLowerCase();
      expect(joined, contains('estimate'));
      expect(joined, contains('quotation'));
      expect(joined, contains('chat'));
      expect(joined, isNot(contains('crew')));
      expect(joined, isNot(contains('construction site')));
      expect(joined, isNot(contains('schedule')));
    });

    test('falls back to a generic welcome without a first name', () {
      expect(homeGuideSteps().first.title, 'Welcome.');
      expect(homeGuideSteps(firstName: 'User').first.title, 'Welcome.');
    });
  });

  group('chatGuideSteps', () {
    test('explains messaging after a shop is selected', () {
      final steps = chatGuideSteps();
      expect(steps, hasLength(3));
      final joined =
          steps.map((s) => '${s.title} ${s.body}').join(' ').toLowerCase();
      expect(joined, contains('chat'));
      expect(joined, contains('pickup'));
      expect(joined, contains('quotation'));
    });
  });
}
