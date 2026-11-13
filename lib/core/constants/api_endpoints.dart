class ApiEndpoints {
  // Satellite APIs
  static const String nasaGpmUrl = 'https://gpm.nasa.gov/data/imerg';
  static const String hlsLandsatSentinelUrl = 'https://cmr.earthdata.nasa.gov/stac/LPCLOUD';
  static const String copernicusSentinel1Url = 'https://catalogue.dataspace.copernicus.eu';
  static const String nasaDemElevationUrl = 'https://earthdata.nasa.gov/nasadem';

  // Market API (DAM Bangladesh)
  static const String bangladeshDamMarketUrl = 'https://dam.gov.bd/daily_market_price';

  // --- AgriGuardian FastAPI backend ---
  // Relative to ApiConfig.baseUrl (lib/core/config/api_config.dart), which
  // already carries the `/api/v1` prefix, so paths here start at the
  // resource, matching backend/api/app/routes.py exactly.
  static const String authEmailRequest = '/auth/email/request';
  static const String authEmailVerify = '/auth/email/verify';
  static const String identityMe = '/identity/me';

  static const String fields = '/fields';

  static String field(String fieldId) => '/fields/$fieldId';

  static String fieldCropCycles(String fieldId) =>
      '/fields/$fieldId/crop-cycles';

  static String cropCycle(String cycleId) => '/crop-cycles/$cycleId';

  // --- Marketplace (Phase 12) ---
  static const String marketplaceListings = '/marketplace/listings';

  static String marketplaceListing(String id) => '/marketplace/listings/$id';

  static const String marketplaceMyListings = '/marketplace/my-listings';

  static String marketplaceListingClose(String id) =>
      '/marketplace/listings/$id/close';

  static String marketplaceListingBids(String id) =>
      '/marketplace/listings/$id/bids';

  static const String marketplaceMyBids = '/marketplace/my-bids';

  static String marketplaceBidWithdraw(String id) =>
      '/marketplace/bids/$id/withdraw';

  static String marketplaceBidAccept(String id) =>
      '/marketplace/bids/$id/accept';

  static const String marketplaceOrders = '/marketplace/orders';

  static String marketplaceOrder(String id) => '/marketplace/orders/$id';
}
