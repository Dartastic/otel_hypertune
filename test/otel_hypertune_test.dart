// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_hypertune/otel_hypertune.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_hypertune-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('query.evaluate records field path + variant + logical type', () async {
    await tracedHypertune<String>(
      operation: 'query.evaluate',
      invoke: () async => const HypertuneCallResult(
        value: 'ok',
        result: HypertuneResult(
          fieldPath: 'root.feature.newOnboarding',
          environment: 'production',
          split: 'us-rollout',
          variant: 'on',
          logicalType: 'Boolean',
          fromCache: true,
          commitId: 'abc123',
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('hypertune query.evaluate')!);
    expect(a['hypertune.field.path'], 'root.feature.newOnboarding');
    expect(a['hypertune.split'], 'us-rollout');
    expect(a['hypertune.variant'], 'on');
    expect(a['hypertune.logical_type'], 'Boolean');
    expect(a['hypertune.commit.id'], 'abc123');
  });

  test('events.log_events records count', () async {
    await tracedHypertune<String>(
      operation: 'events.log_events',
      invoke: () async => const HypertuneCallResult(
        value: 'ok',
        result: HypertuneResult(eventsLogged: 50),
      ),
    );
    final a = attrsOf(spans.findSpanByName('hypertune events.log_events')!);
    expect(a['hypertune.events_logged'], 50);
  });

  test('suppression skips spans', () async {
    await runWithoutHypertuneInstrumentationAsync(() async {
      await tracedHypertune<String>(
        operation: 'splits.list',
        invoke: () async => const HypertuneCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('hypertune '), isEmpty);
  });
}
