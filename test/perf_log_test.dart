// PerfLog prints one line per metric for a begun session, nothing for a
// session that was never begun, and nothing again once a session has ended.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/core/perf/perf_log.dart';

void main() {
  final lines = <String>[];

  setUp(() {
    lines.clear();
    PerfLog.reset();
    PerfLog.printer = lines.add;
  });

  tearDown(PerfLog.reset);

  testWidgets('an unknown session prints nothing', (tester) async {
    PerfLog.response('never_begun');
    PerfLog.screenShown('never_begun');
    PerfLog.contentReady('never_begun');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(lines, isEmpty);
  });

  testWidgets('each metric prints once, after the frame is drawn', (
    tester,
  ) async {
    PerfLog.begin('cycle');
    PerfLog.response('cycle');
    PerfLog.response('cycle');
    PerfLog.screenShown('cycle');
    PerfLog.screenShown('cycle');

    // load waits for the new screen's first frame.
    expect(lines, hasLength(1));
    await tester.pumpWidget(const SizedBox());

    PerfLog.contentReady('cycle');
    PerfLog.contentReady('cycle');
    await tester.pump();
    await tester.pump();

    expect(lines, hasLength(3));
    expect(lines[0], matches(RegExp(r'^PERF cycle response \d+ ms$')));
    expect(lines[1], matches(RegExp(r'^PERF cycle load \d+ ms$')));
    expect(lines[2], matches(RegExp(r'^PERF cycle render \d+ ms$')));
  });

  testWidgets('an ended session prints nothing more', (tester) async {
    PerfLog.begin('cycle');
    PerfLog.screenShown('cycle');
    PerfLog.contentReady('cycle');
    await tester.pumpWidget(const SizedBox());
    expect(lines, [
      matches(RegExp(r'^PERF cycle load \d+ ms$')),
      matches(RegExp(r'^PERF cycle render \d+ ms$')),
    ]);

    // A stream delivering again, or a rebuild, after the session ended.
    PerfLog.response('cycle');
    PerfLog.screenShown('cycle');
    PerfLog.contentReady('cycle');
    await tester.pump();
    await tester.pump();

    expect(lines, hasLength(2));
  });

  testWidgets('a session with no screen times render from the response', (
    tester,
  ) async {
    PerfLog.begin('reply');
    PerfLog.response('reply');
    PerfLog.contentReady('reply');
    await tester.pumpWidget(const SizedBox());

    expect(lines, [
      matches(RegExp(r'^PERF reply response \d+ ms$')),
      matches(RegExp(r'^PERF reply render \d+ ms$')),
    ]);
  });

  testWidgets('begin again restarts the session', (tester) async {
    PerfLog.begin('cycle');
    PerfLog.response('cycle');
    PerfLog.begin('cycle');
    PerfLog.response('cycle');
    await tester.pump();

    expect(lines, hasLength(2));
  });
}
