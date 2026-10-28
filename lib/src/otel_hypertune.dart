// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_hypertune_suppression.dart';

const _tracerName = 'dartastic_otel_libs_hypertune';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class HypertuneResult {
  /// Creates a result.
  const HypertuneResult({
    this.fieldPath,
    this.environment,
    this.split,
    this.variant,
    this.logicalType,
    this.fromCache,
    this.commitId,
    this.eventsLogged,
    this.requestId,
    this.statusCode,
  });

  /// Dotted GraphQL field path (Hypertune's flag identifier).
  final String? fieldPath;

  /// `production` / `development` / custom env.
  final String? environment;

  /// `split_key` matched.
  final String? split;

  /// Variant chosen within the split.
  final String? variant;

  /// `Boolean` / `String` / `Int` / `Float` / `Enum` / Object — type
  /// returned (Hypertune is strongly typed).
  final String? logicalType;

  /// Whether the value came from local cache (Hypertune is
  /// edge-evaluated).
  final bool? fromCache;

  /// Git-like `commit_id` of the flag config (drives cache
  /// invalidation).
  final String? commitId;

  /// Number of events logged in a `events.log_events` call (analytics
  /// fan-out cost).
  final int? eventsLogged;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class HypertuneCallResult<T> {
  /// Creates a call result.
  const HypertuneCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final HypertuneResult? result;
}

/// Wraps a Hypertune call in a CLIENT span. [operation] is one of
/// `query.evaluate`, `query.bulk_evaluate`, `events.log_events`,
/// `splits.list`, `splits.update`, `commits.list`, `commits.publish`,
/// `init.fetch`.
Future<T> tracedHypertune<T>({
  required String operation,
  required Future<HypertuneCallResult<T>> Function() invoke,
}) async {
  if (hypertuneInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'hypertune',
    'rpc.method': operation,
    'hypertune.operation': operation,
  };

  final span = _tracer().startSpan(
    'hypertune $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.fieldPath != null) {
        extras.add(OTelAPI.attributeString(
          'hypertune.field.path',
          r.result!.fieldPath!,
        ));
      }
      if (r.result!.environment != null) {
        extras.add(OTelAPI.attributeString(
          'hypertune.environment',
          r.result!.environment!,
        ));
      }
      if (r.result!.split != null) {
        extras.add(OTelAPI.attributeString(
          'hypertune.split',
          r.result!.split!,
        ));
      }
      if (r.result!.variant != null) {
        extras.add(OTelAPI.attributeString(
          'hypertune.variant',
          r.result!.variant!,
        ));
      }
      if (r.result!.logicalType != null) {
        extras.add(OTelAPI.attributeString(
          'hypertune.logical_type',
          r.result!.logicalType!,
        ));
      }
      if (r.result!.fromCache != null) {
        extras.add(OTelAPI.attributeBool(
          'hypertune.from_cache',
          r.result!.fromCache!,
        ));
      }
      if (r.result!.commitId != null) {
        extras.add(OTelAPI.attributeString(
          'hypertune.commit.id',
          r.result!.commitId!,
        ));
      }
      if (r.result!.eventsLogged != null) {
        extras.add(OTelAPI.attributeInt(
          'hypertune.events_logged',
          r.result!.eventsLogged!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'hypertune.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Hypertune HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
