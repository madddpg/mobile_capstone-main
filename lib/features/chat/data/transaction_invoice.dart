import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';

/// One accepted line item on an official quotation invoice.
class TransactionInvoiceItem {
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double total;
  final String? category;
  final String? notes;

  const TransactionInvoiceItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.total,
    this.category,
    this.notes,
  });

  factory TransactionInvoiceItem.fromMap(Map<String, dynamic> map) {
    final name = quotedItemName(map);
    final rawQty = map['quantity'] ?? map['qty'] ?? 1;
    final quantity = rawQty is num
        ? rawQty.toDouble()
        : (double.tryParse('$rawQty'.trim()) ?? 1.0);
    final unit = (map['unit'] ?? map['uom'] ?? 'pcs').toString().trim();

    final rawPrice = map['unitPrice'] ?? map['price'] ?? 0;
    final unitPrice = rawPrice is num
        ? rawPrice.toDouble()
        : (double.tryParse('$rawPrice'.replaceAll(',', '').trim()) ?? 0.0);

    final total = lineTotalOf(map);

    return TransactionInvoiceItem(
      name: name.isNotEmpty ? name : 'Material Item',
      quantity: quantity > 0 ? quantity : 1.0,
      unit: unit.isNotEmpty ? unit : 'pcs',
      unitPrice: unitPrice > 0 ? unitPrice : (total > 0 && quantity > 0 ? total / quantity : 0.0),
      total: total > 0 ? total : (unitPrice * quantity),
      category: map['category']?.toString(),
      notes: map['lineNote']?.toString() ?? map['note']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'total': total,
    if (category != null) 'category': category,
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
  };
}

/// Official Quotation & Transaction Invoice model.
///
/// Generated when a hardware shop accepts/confirms an order, dispatched directly
/// into the chat thread under `conversations/{postId}_{shopId}/messages`.
class TransactionInvoice {
  final String quotationId;
  final String projectId;
  final double acceptedTotal;
  final String projectTitle;
  final String shopName;
  final String builderName;
  final DateTime issuedAt;
  final List<TransactionInvoiceItem> items;
  final Map<String, dynamic> quotationSnapshot;
  final bool isConfirmed;

  const TransactionInvoice({
    required this.quotationId,
    required this.projectId,
    required this.acceptedTotal,
    required this.projectTitle,
    required this.shopName,
    required this.builderName,
    required this.issuedAt,
    required this.items,
    this.quotationSnapshot = const {},
    this.isConfirmed = true,
  });

  /// True when [msg] represents an automated transaction invoice message.
  static bool isInvoiceMessage(Map<String, dynamic> msg) {
    final type = (msg['type'] ?? '').toString().trim().toLowerCase();
    if (type == 'quotation_invoice' || type == 'invoice') return true;

    final text = (msg['text'] ?? '').toString().trim();
    if (text.startsWith('[OFFICIAL_TRANSACTION_INVOICE]')) return true;

    return false;
  }

  /// Parses a transaction invoice from a Firestore chat message map.
  factory TransactionInvoice.fromMessage(
    Map<String, dynamic> msg, {
    Map<String, dynamic>? conversation,
    String? defaultShopName,
    String? defaultBuilderName,
  }) {
    final rawSnapshot = msg['quotationSnapshot'];
    final snapshot = rawSnapshot is Map
        ? Map<String, dynamic>.from(rawSnapshot)
        : <String, dynamic>{};

    final qId = (msg['quotationId'] ??
            snapshot['quotationId'] ??
            snapshot['id'] ??
            conversation?['quotationId'] ??
            '')
        .toString()
        .trim();

    final pId = (msg['projectId'] ??
            msg['postId'] ??
            snapshot['projectId'] ??
            snapshot['postId'] ??
            conversation?['projectId'] ??
            conversation?['postId'] ??
            '')
        .toString()
        .trim();

    final double total;
    final rawTotal = msg['acceptedTotal'] ??
        snapshot['acceptedTotal'] ??
        snapshot['total'] ??
        snapshot['amount'];
    if (rawTotal is num) {
      total = rawTotal.toDouble();
    } else {
      total = double.tryParse('${rawTotal ?? ''}'.replaceAll(',', '').trim()) ?? 0.0;
    }

    final pTitle = (snapshot['projectTitle'] ??
            snapshot['projectName'] ??
            conversation?['projectTitle'] ??
            conversation?['projectName'] ??
            '')
        .toString()
        .trim();

    final sName = (snapshot['shopName'] ??
            conversation?['shopName'] ??
            defaultShopName ??
            '')
        .toString()
        .trim();

    final bName = (snapshot['builderName'] ??
            snapshot['ownerName'] ??
            conversation?['builderName'] ??
            conversation?['ownerName'] ??
            defaultBuilderName ??
            '')
        .toString()
        .trim();

    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final issued = parseDate(
      msg['createdAt'] ?? snapshot['acceptedAt'] ?? snapshot['createdAt'],
    );

    // Extract accepted items from snapshot
    final parsedItems = <TransactionInvoiceItem>[];
    final lines = quotationItems(snapshot);
    for (final line in lines) {
      // If quotation was partially accepted, skip dropped items
      if (line['accepted'] == false) continue;
      if (isUnavailableLine(line)) continue;
      parsedItems.add(TransactionInvoiceItem.fromMap(line));
    }

    return TransactionInvoice(
      quotationId: qId.isNotEmpty ? qId : 'Q-TRANSACTION',
      projectId: pId.isNotEmpty ? pId : 'PROJECT',
      acceptedTotal: total,
      projectTitle: pTitle.isNotEmpty ? pTitle : 'Renovation Project',
      shopName: sName.isNotEmpty ? sName : 'Hardware Shop',
      builderName: bName.isNotEmpty ? bName : 'Homeowner / Builder',
      issuedAt: issued,
      items: parsedItems,
      quotationSnapshot: snapshot,
      isConfirmed: true,
    );
  }

  /// Compact, user-facing reference string.
  String get referenceNumber {
    final clean = quotationId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (clean.length > 8) {
      return clean.substring(clean.length - 8).toUpperCase();
    }
    return clean.isNotEmpty ? clean.toUpperCase() : 'TRANSACTION';
  }

  /// Count of items accepted on this transaction.
  int get itemsCount => items.isNotEmpty
      ? items.length
      : ((quotationSnapshot['itemsCount'] is num)
          ? (quotationSnapshot['itemsCount'] as num).toInt()
          : 0);

  /// Formatted total amount in Philippine Peso with 2 decimals (e.g. ₱45,250.00).
  String get formattedTotal => '₱${formatNumber(acceptedTotal)}';

  /// Standard comma-separated number formatting.
  static String formatNumber(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final dec = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(whole[i]);
    }
    return '${buffer.toString()}.$dec';
  }

  /// Formats date for receipt / invoice display (e.g. October 17, 2026 · 9:51 AM).
  String get formattedIssuedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[issuedAt.month - 1];
    final hour12 = issuedAt.hour % 12 == 0 ? 12 : issuedAt.hour % 12;
    final ampm = issuedAt.hour >= 12 ? 'PM' : 'AM';
    final minute = issuedAt.minute.toString().padLeft(2, '0');
    return '$m ${issuedAt.day}, ${issuedAt.year} · $hour12:$minute $ampm';
  }

  /// Asynchronously fetches full quotation items from Firestore if snapshot was empty.
  Future<TransactionInvoice> resolveFromFirestoreIfEmpty({
    FirebaseFirestore? firestore,
  }) async {
    if (items.isNotEmpty) return this;
    if (projectId.isEmpty || quotationId.isEmpty) return this;

    final db = firestore ?? FirebaseFirestore.instance;
    try {
      final snap = await db
          .collection('projectPosts')
          .doc(projectId)
          .collection('quotations')
          .doc(quotationId)
          .get();

      if (!snap.exists) return this;
      final data = snap.data() ?? {};
      final lines = quotationItems(data);
      final resolved = <TransactionInvoiceItem>[];
      for (final line in lines) {
        if (line['accepted'] == false) continue;
        if (isUnavailableLine(line)) continue;
        resolved.add(TransactionInvoiceItem.fromMap(line));
      }

      double resolvedTotal = acceptedTotal;
      if (resolvedTotal <= 0) {
        final raw = data['acceptedTotal'] ?? data['amount'] ?? data['total'];
        if (raw is num) resolvedTotal = raw.toDouble();
      }

      return TransactionInvoice(
        quotationId: quotationId,
        projectId: projectId,
        acceptedTotal: resolvedTotal > 0 ? resolvedTotal : acceptedTotal,
        projectTitle: projectTitle,
        shopName: (data['shopName']?.toString().isNotEmpty ?? false)
            ? data['shopName'].toString()
            : shopName,
        builderName: builderName,
        issuedAt: issuedAt,
        items: resolved.isNotEmpty ? resolved : items,
        quotationSnapshot: data,
        isConfirmed: isConfirmed,
      );
    } catch (_) {
      return this;
    }
  }
}
