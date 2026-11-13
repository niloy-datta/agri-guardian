/// Typed marketplace domain models.
///
/// Quantity fields (`NUMERIC(18,3)` on the backend) are kept as exact
/// decimal strings end to end - never parsed into a `double` - so a value
/// like "1200.500" round-trips without floating-point drift. Money is
/// always an `int` minor-unit count. See `exact_numbers.dart` for the
/// conversion helpers used by input forms.
library;

/// Reads a backend Decimal field defensively. Pydantic emits `Decimal` as
/// a JSON string by default (Task 12's own warning), so the common case
/// is a `String` here - kept exactly as received. If a raw JSON number
/// ever arrives instead, the precision loss already happened before this
/// code runs (Dart's JSON decoder parsed it into an `int`/`double`); an
/// `int` converts back exactly, a `double` does not and is only a
/// fallback, never the expected path for a NUMERIC(18,3) field.
String decimalStringFrom(dynamic value) {
  if (value == null) return '0';
  if (value is String) return value;
  if (value is int) return value.toString();
  return value.toString();
}

class SellerSummary {
  final String farmerId;
  final String? displayName;

  const SellerSummary({required this.farmerId, this.displayName});

  factory SellerSummary.fromJson(Map<String, dynamic> json) => SellerSummary(
        farmerId: json['farmer_id'] as String,
        displayName: json['display_name'] as String?,
      );
}

class BuyerSummary {
  final String buyerId;
  final String? displayName;

  const BuyerSummary({required this.buyerId, this.displayName});

  factory BuyerSummary.fromJson(Map<String, dynamic> json) => BuyerSummary(
        buyerId: json['buyer_id'] as String,
        displayName: json['display_name'] as String?,
      );
}

/// The compact listing context carried on a [MarketplaceBid] or
/// [MarketplaceOrder] - some fields are only populated by one of the two
/// backend responses, so both are nullable here rather than forcing a
/// second model.
class ListingSummary {
  final String listingId;
  final String productName;
  final String listingKind;
  final String? quantityUnit;
  final String? district;
  final String? status;

  const ListingSummary({
    required this.listingId,
    required this.productName,
    required this.listingKind,
    this.quantityUnit,
    this.district,
    this.status,
  });

  factory ListingSummary.fromJson(Map<String, dynamic> json) => ListingSummary(
        listingId: (json['listing_id'] ?? json['id']) as String,
        productName: json['product_name'] as String,
        listingKind: json['listing_kind'] as String,
        quantityUnit: json['quantity_unit'] as String?,
        district: json['district'] as String?,
        status: json['status'] as String?,
      );
}

class MarketplaceListing {
  final String id;
  final String sellerFarmerId;
  final SellerSummary seller;
  final String? fieldId;
  final String? cropCycleId;
  final String listingKind;
  final String? productCode;
  final String productName;
  final String? description;
  final String quantityTotal;
  final String quantityAvailable;
  final String quantityUnit;
  final int? askingPriceMinor;
  final String currency;
  final String? grade;
  final DateTime? harvestDate;
  final DateTime? availableFrom;
  final bool isFutureHarvest;
  final String deliveryMode;
  final String countryCode;
  final String? region;
  final String? district;
  final String? upazila;
  final Map<String, dynamic> attributes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const MarketplaceListing({
    required this.id,
    required this.sellerFarmerId,
    required this.seller,
    this.fieldId,
    this.cropCycleId,
    required this.listingKind,
    this.productCode,
    required this.productName,
    this.description,
    required this.quantityTotal,
    required this.quantityAvailable,
    required this.quantityUnit,
    this.askingPriceMinor,
    required this.currency,
    this.grade,
    this.harvestDate,
    this.availableFrom,
    required this.isFutureHarvest,
    required this.deliveryMode,
    required this.countryCode,
    this.region,
    this.district,
    this.upazila,
    required this.attributes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isSoldOut => status == 'SOLD_OUT';
  bool get isClosed => status == 'CLOSED' || status == 'CANCELLED';

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    return MarketplaceListing(
      id: json['id'] as String,
      sellerFarmerId: json['seller_farmer_id'] as String,
      seller: SellerSummary.fromJson(Map<String, dynamic>.from(json['seller'] as Map)),
      fieldId: json['field_id'] as String?,
      cropCycleId: json['crop_cycle_id'] as String?,
      listingKind: json['listing_kind'] as String,
      productCode: json['product_code'] as String?,
      productName: json['product_name'] as String,
      description: json['description'] as String?,
      quantityTotal: decimalStringFrom(json['quantity_total']),
      quantityAvailable: decimalStringFrom(json['quantity_available']),
      quantityUnit: json['quantity_unit'] as String,
      askingPriceMinor: json['asking_price_minor'] as int?,
      currency: json['currency'] as String,
      grade: json['grade'] as String?,
      harvestDate: json['harvest_date'] == null
          ? null
          : DateTime.tryParse(json['harvest_date'] as String),
      availableFrom: json['available_from'] == null
          ? null
          : DateTime.tryParse(json['available_from'] as String),
      isFutureHarvest: json['is_future_harvest'] as bool? ?? false,
      deliveryMode: json['delivery_mode'] as String,
      countryCode: json['country_code'] as String,
      region: json['region'] as String?,
      district: json['district'] as String?,
      upazila: json['upazila'] as String?,
      attributes: json['attributes'] == null
          ? const {}
          : Map<String, dynamic>.from(json['attributes'] as Map),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int,
    );
  }
}

class MarketplaceBid {
  final String id;
  final String listingId;
  final String buyerId;
  final BuyerSummary buyer;
  final ListingSummary listing;
  final String quantity;
  final int unitPriceMinor;
  final String currency;
  final String? note;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const MarketplaceBid({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.buyer,
    required this.listing,
    required this.quantity,
    required this.unitPriceMinor,
    required this.currency,
    this.note,
    required this.status,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  bool get isActive => status == 'ACTIVE';

  factory MarketplaceBid.fromJson(Map<String, dynamic> json) {
    return MarketplaceBid(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      buyerId: json['buyer_id'] as String,
      buyer: BuyerSummary.fromJson(Map<String, dynamic>.from(json['buyer'] as Map)),
      listing: ListingSummary.fromJson(Map<String, dynamic>.from(json['listing'] as Map)),
      quantity: decimalStringFrom(json['quantity']),
      unitPriceMinor: json['unit_price_minor'] as int,
      currency: json['currency'] as String,
      note: json['note'] as String?,
      status: json['status'] as String,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int,
    );
  }
}

class BidAcceptResult {
  final MarketplaceBid bid;
  final String orderId;

  const BidAcceptResult({required this.bid, required this.orderId});

  factory BidAcceptResult.fromJson(Map<String, dynamic> json) => BidAcceptResult(
        bid: MarketplaceBid.fromJson(Map<String, dynamic>.from(json['bid'] as Map)),
        orderId: json['order_id'] as String,
      );
}

class MarketplaceOrder {
  final String id;
  final String listingId;
  final ListingSummary listing;
  final String acceptedBidId;
  final String sellerFarmerId;
  final String buyerId;
  final String? sellerDisplayName;
  final String? buyerDisplayName;
  final String quantity;
  final String quantityUnit;
  final int unitPriceMinor;
  final int totalAmountMinor;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const MarketplaceOrder({
    required this.id,
    required this.listingId,
    required this.listing,
    required this.acceptedBidId,
    required this.sellerFarmerId,
    required this.buyerId,
    this.sellerDisplayName,
    this.buyerDisplayName,
    required this.quantity,
    required this.quantityUnit,
    required this.unitPriceMinor,
    required this.totalAmountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  factory MarketplaceOrder.fromJson(Map<String, dynamic> json) {
    return MarketplaceOrder(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      listing: ListingSummary.fromJson(Map<String, dynamic>.from(json['listing'] as Map)),
      acceptedBidId: json['accepted_bid_id'] as String,
      sellerFarmerId: json['seller_farmer_id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerDisplayName: json['seller_display_name'] as String?,
      buyerDisplayName: json['buyer_display_name'] as String?,
      quantity: decimalStringFrom(json['quantity']),
      quantityUnit: json['quantity_unit'] as String,
      unitPriceMinor: json['unit_price_minor'] as int,
      totalAmountMinor: json['total_amount_minor'] as int,
      currency: json['currency'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int,
    );
  }
}

/// Mirrors FastAPI's `CursorPage[T]` envelope exactly (see
/// `FieldsPage` in `fields/data/field_repository.dart` for the same
/// pattern already established for fields).
class MarketplacePage<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  const MarketplacePage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory MarketplacePage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return MarketplacePage<T>(
      items: (json['items'] as List)
          .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
