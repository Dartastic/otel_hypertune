// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_hypertune/otel_hypertune.dart';

/// Traces Hypertune calls with OpenTelemetry.
///
/// `otel_hypertune` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Hypertune call in
/// [tracedHypertune]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'hypertune-example');

  // Wraps a Hypertune call in a CLIENT span.
  final hypertuneId = await tracedHypertune<String>(
    operation: 'commits.publish',
    invoke: () async {
      // Make the Hypertune call here, then report what it returned.
      const id = 'hypertune_8f3a2c';
      return const HypertuneCallResult(
          value: id,
          result: HypertuneResult(
              fieldPath: '/v1/orders',
              environment: 'production',
              split: 'split_key',
              variant: 'example',
              logicalType: 'Boolean',
              fromCache: true,
              commitId: 'commit_id',
              eventsLogged: 1,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedHypertune commits.publish returned $hypertuneId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutHypertuneInstrumentationAsync.
  await runWithoutHypertuneInstrumentationAsync(
    () => tracedHypertune<String>(
      operation: 'commits.publish',
      invoke: () async {
        const id = 'hypertune_8f3a2c';
        return const HypertuneCallResult(
            value: id,
            result: HypertuneResult(
                fieldPath: '/v1/orders',
                environment: 'production',
                split: 'split_key',
                variant: 'example',
                logicalType: 'Boolean',
                fromCache: true,
                commitId: 'commit_id',
                eventsLogged: 1,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
