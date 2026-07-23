import '../models/printer_config.dart';
import '../models/print_job.dart';

/// Resolves which physical printer(s) should handle a given print job.
///
/// Each [PrinterConfig] declares what it is responsible for via
/// [PrinterConfig.handledStations] and [PrinterConfig.handlesBill].
/// The router matches incoming job intent against these declarations.
class PrinterRouter {
  final List<PrinterConfig> printers;

  PrinterRouter(this.printers);

  // ── KOT / CancelKOT ─────────────────────────────────────────────────────
  /// Returns all printer IDs whose [handledStations] contains [station].
  /// Logs a warning if no printer is configured for the station.
  List<String> resolveForStation(String station) {
    final upper = station.trim().toUpperCase();
    final matched = printers
        .where((p) => p.handledStations.contains(upper))
        .map((p) => p.id)
        .toList();

    if (matched.isEmpty) {
      print('[Router] ⚠️ No printer configured for station=$upper — job skipped');
    } else {
      print('[Router] ✅ station=$upper → ${matched.join(', ')}');
    }
    return matched;
  }

  // ── Bill ─────────────────────────────────────────────────────────────────
  /// Returns all printer IDs where [handlesBill] is true.
  List<String> resolveForBill() {
    final matched = printers
        .where((p) => p.handlesBill)
        .map((p) => p.id)
        .toList();

    if (matched.isEmpty) {
      print('[Router] ⚠️ No bill printer configured — bill job skipped');
    } else {
      print('[Router] ✅ bill → ${matched.join(', ')}');
    }
    return matched;
  }

  // ── Convenience ──────────────────────────────────────────────────────────
  /// Resolves by [PrintType]. Pass [station] for KOT / cancelKOT jobs.
  List<String> resolve(PrintType type, {String? station}) {
    if (type == PrintType.bill) return resolveForBill();
    if (station != null) return resolveForStation(station);
    print('[Router] ⚠️ resolve() called for KOT without station — skipped');
    return [];
  }

  // ── Diagnostics ──────────────────────────────────────────────────────────
  /// Returns printer configs that have no stations and handlesBill=false.
  List<PrinterConfig> get orphanPrinters => printers
      .where((p) => p.handledStations.isEmpty && !p.handlesBill)
      .toList();

  /// Returns all stations that are NOT covered by any printer.
  Set<String> uncoveredStations(Set<String> allStations) {
    final covered = printers
        .expand((p) => p.handledStations)
        .map((s) => s.toUpperCase())
        .toSet();
    return allStations.map((s) => s.toUpperCase()).toSet().difference(covered);
  }
}
