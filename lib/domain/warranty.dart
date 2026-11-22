import '../core/hlc.dart';
import 'change.dart';
import 'views.dart';

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
double? _num(Object? v) => v is num ? v.toDouble() : null;
int? _int(Object? v) => v is num ? v.toInt() : null;
String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

DateTime _clockTime(String clock) {
  if (clock.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.fromMillisecondsSinceEpoch(Hlc.parse(clock).millis);
}

/// Adds whole months, clamping the day (31 Jan + 1 month = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

/// What kind of extra cover an appliance has after (or instead of) the
/// maker's warranty.
enum ExtraCoverKind {
  extended('extended'),
  amc('amc');

  const ExtraCoverKind(this.code);
  final String code;

  static ExtraCoverKind fromCode(Object? code) =>
      ExtraCoverKind.values.firstWhere((k) => k.code == code, orElse: () => ExtraCoverKind.extended);
}

/// Where a cover period stands today.
enum CoverState { active, expiringSoon, expired, unknown }

/// One period of cover: the maker's warranty, or an extended warranty / AMC.
class Coverage {
  const Coverage({required this.ends, this.starts});

  final DateTime? starts;
  final DateTime? ends;

  /// Days from [today] to the last covered day (negative once over).
  int? daysLeft(DateTime today) => ends == null ? null : dateOnly(ends!).difference(dateOnly(today)).inDays;

  CoverState state(DateTime today, {int soonDays = 30}) {
    final d = daysLeft(today);
    if (d == null) return CoverState.unknown;
    if (d < 0) return CoverState.expired;
    if (d <= soonDays) return CoverState.expiringSoon;
    return CoverState.active;
  }
}

/// An appliance or gadget and its warranty paperwork.
class Appliance {
  const Appliance({
    required this.id,
    required this.familyId,
    required this.name,
    this.brand,
    this.model,
    this.serial,
    this.purchaseDate,
    this.store,
    this.price,
    this.invoiceNo,
    this.warrantyMonths,
    this.warrantyEnds,
    this.extraKind = ExtraCoverKind.extended,
    this.extraProvider,
    this.extraEnds,
    this.extraCost,
    this.helpline,
    this.serviceCentre,
    this.serviceCentrePhone,
    this.note,
    this.photos = const [],
    this.createdBy,
    this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  final String familyId;
  final String name;
  final String? brand;
  final String? model;
  final String? serial;
  final DateTime? purchaseDate;
  final String? store;
  final double? price;
  final String? invoiceNo;

  /// Length of the maker's warranty; used when [warrantyEnds] isn't set.
  final int? warrantyMonths;

  /// Explicit end of the maker's warranty (wins over [warrantyMonths]).
  final DateTime? warrantyEnds;

  final ExtraCoverKind extraKind;
  final String? extraProvider;
  final DateTime? extraEnds;
  final double? extraCost;

  final String? helpline;
  final String? serviceCentre;
  final String? serviceCentrePhone;
  final String? note;

  /// Photo ids (content hashes) of the bill, warranty card and so on.
  final List<String> photos;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final bool deleted;

  /// The maker's warranty: explicit end date, or purchase date + months.
  Coverage get warranty {
    final ends = warrantyEnds ??
        (purchaseDate != null && warrantyMonths != null && warrantyMonths! > 0
            ? addMonths(purchaseDate!, warrantyMonths!).subtract(const Duration(days: 1))
            : null);
    return Coverage(starts: purchaseDate, ends: ends);
  }

  /// Extended warranty or AMC, if any.
  Coverage? get extra => extraEnds == null ? null : Coverage(ends: extraEnds, starts: warranty.ends);

  bool get hasExtra => extraEnds != null || extraProvider != null;

  /// The cover that lasts longest; what "under warranty till" refers to.
  Coverage get bestCover {
    final w = warranty, x = extra;
    if (x?.ends == null) return w;
    if (w.ends == null || x!.ends!.isAfter(w.ends!)) return x!;
    return w;
  }

  /// Whether [bestCover] is the extended warranty / AMC.
  bool get bestIsExtra {
    final w = warranty.ends, x = extraEnds;
    return x != null && (w == null || x.isAfter(w));
  }

  /// Whether the item is covered on [day] by any cover.
  bool coveredOn(DateTime day) {
    final ends = bestCover.ends;
    return ends != null && !dateOnly(day).isAfter(dateOnly(ends));
  }

  factory Appliance.fromRecord(RecordState r) {
    final f = r.fields;
    return Appliance(
      id: r.id,
      familyId: r.familyId,
      name: _str(f['name']) ?? '?',
      brand: _str(f['brand']),
      model: _str(f['model']),
      serial: _str(f['serial']),
      purchaseDate: _date(f['purchaseDate']),
      store: _str(f['store']),
      price: _num(f['price']),
      invoiceNo: _str(f['invoiceNo']),
      warrantyMonths: _int(f['warrantyMonths']),
      warrantyEnds: _date(f['warrantyEnds']),
      extraKind: ExtraCoverKind.fromCode(f['extraKind']),
      extraProvider: _str(f['extraProvider']),
      extraEnds: _date(f['extraEnds']),
      extraCost: _num(f['extraCost']),
      helpline: _str(f['helpline']),
      serviceCentre: _str(f['serviceCentre']),
      serviceCentrePhone: _str(f['serviceCentrePhone']),
      note: _str(f['note']),
      photos: [
        for (final p in (f['photos'] as List?) ?? const [])
          if (p is String && p.isNotEmpty) p,
      ],
      createdBy: _str(f['createdBy']),
      createdAt: _date(f['createdAt']),
      updatedAt: _clockTime(r.updatedClock),
      deleted: r.isDeleted,
    );
  }
}

/// The editable fields of an appliance, as the add/edit form produces them.
class ApplianceDraft {
  const ApplianceDraft({
    required this.name,
    this.brand,
    this.model,
    this.serial,
    this.purchaseDate,
    this.store,
    this.price,
    this.invoiceNo,
    this.warrantyMonths,
    this.warrantyEnds,
    this.extraKind = ExtraCoverKind.extended,
    this.extraProvider,
    this.extraEnds,
    this.extraCost,
    this.helpline,
    this.serviceCentre,
    this.serviceCentrePhone,
    this.note,
    this.photos = const [],
  });

  final String name;
  final String? brand;
  final String? model;
  final String? serial;
  final DateTime? purchaseDate;
  final String? store;
  final double? price;
  final String? invoiceNo;
  final int? warrantyMonths;
  final DateTime? warrantyEnds;
  final ExtraCoverKind extraKind;
  final String? extraProvider;
  final DateTime? extraEnds;
  final double? extraCost;
  final String? helpline;
  final String? serviceCentre;
  final String? serviceCentrePhone;
  final String? note;
  final List<String> photos;

  factory ApplianceDraft.of(Appliance a) => ApplianceDraft(
        name: a.name,
        brand: a.brand,
        model: a.model,
        serial: a.serial,
        purchaseDate: a.purchaseDate,
        store: a.store,
        price: a.price,
        invoiceNo: a.invoiceNo,
        warrantyMonths: a.warrantyMonths,
        warrantyEnds: a.warrantyEnds,
        extraKind: a.extraKind,
        extraProvider: a.extraProvider,
        extraEnds: a.extraEnds,
        extraCost: a.extraCost,
        helpline: a.helpline,
        serviceCentre: a.serviceCentre,
        serviceCentrePhone: a.serviceCentrePhone,
        note: a.note,
        photos: a.photos,
      );

  static String _day(DateTime d) => DateTime(d.year, d.month, d.day).toIso8601String();
  static String? _t(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  /// Fields to write. [includePrice] is false for people who can't see
  /// money, so saving their form never clears a price they couldn't see.
  Map<String, Object?> toFields({bool includePrice = true}) => {
        'name': name.trim(),
        'brand': _t(brand),
        'model': _t(model),
        'serial': _t(serial),
        'purchaseDate': purchaseDate == null ? null : _day(purchaseDate!),
        'store': _t(store),
        if (includePrice) 'price': price,
        'invoiceNo': _t(invoiceNo),
        'warrantyMonths': warrantyMonths,
        'warrantyEnds': warrantyEnds == null ? null : _day(warrantyEnds!),
        'extraKind': extraKind.code,
        'extraProvider': _t(extraProvider),
        'extraEnds': extraEnds == null ? null : _day(extraEnds!),
        if (includePrice) 'extraCost': extraCost,
        'helpline': _t(helpline),
        'serviceCentre': _t(serviceCentre),
        'serviceCentrePhone': _t(serviceCentrePhone),
        'note': _t(note),
        'photos': photos,
      };
}

/// A service or repair visit for an appliance.
class ServiceVisit {
  const ServiceVisit({
    required this.id,
    required this.applianceId,
    required this.date,
    required this.issue,
    this.technician,
    this.cost,
    this.covered = false,
    this.note,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String applianceId;
  final DateTime date;
  final String issue;
  final String? technician;
  final double? cost;

  /// Whether the visit was free under warranty or AMC.
  final bool covered;
  final String? note;
  final String? createdBy;
  final DateTime? createdAt;

  factory ServiceVisit.fromRecord(RecordState r) {
    final f = r.fields;
    return ServiceVisit(
      id: r.id,
      applianceId: _str(f['applianceId']) ?? '',
      date: _date(f['date']) ?? _clockTime(r.updatedClock),
      issue: _str(f['issue']) ?? '',
      technician: _str(f['technician']),
      cost: _num(f['cost']),
      covered: f['covered'] == true,
      note: _str(f['note']),
      createdBy: _str(f['createdBy']),
      createdAt: _date(f['createdAt']),
    );
  }
}

/// Sorting for the Warranties tab: soonest-ending cover first, then items
/// with no known end, then expired ones (most recently expired first).
int compareAppliances(Appliance a, Appliance b, DateTime today) {
  int rank(Appliance x) => switch (x.bestCover.state(today)) {
        CoverState.expiringSoon => 0,
        CoverState.active => 1,
        CoverState.unknown => 2,
        CoverState.expired => 3,
      };
  final r = rank(a).compareTo(rank(b));
  if (r != 0) return r;
  final ae = a.bestCover.ends, be = b.bestCover.ends;
  if (ae != null && be != null) {
    final c = rank(a) == 3 ? be.compareTo(ae) : ae.compareTo(be);
    if (c != 0) return c;
  }
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
