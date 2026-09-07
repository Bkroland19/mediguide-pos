import 'package:user_app/core/network/api_client.dart';

enum CollectionOperation {
  loadCollections,
  loadCollection,
  loadMoreCollections,
  loadMoreGuidelines,
  createCollection,
  updateCollection,
  deleteCollection,
  addGuideline,
  removeGuideline,
}

/// Canonical, user-safe wording for the collections workflow.
///
/// Keep transport and persistence details out of the UI. Screens display these
/// strings through `AppMessage`; full exceptions remain available to logging.
abstract final class CollectionMessages {
  static const created = 'Collection created.';
  static const updated = 'Collection updated.';
  static const deleted = 'Collection deleted.';
  static const guidelineRemoved = 'Guideline removed from collection.';
  static const authenticationRequired =
      'Sign in to create and sync your guideline collections.';

  static String guidelineSaved(String collectionName) =>
      'Saved to “$collectionName”.';

  static String guidelineAlreadySaved(String collectionName) =>
      'Already saved in “$collectionName”.';

  static String failure(Object error, CollectionOperation operation) {
    if (error is BackendApiException) {
      if (error.statusCode == 0) {
        return switch (operation) {
          CollectionOperation.createCollection ||
          CollectionOperation.updateCollection ||
          CollectionOperation.deleteCollection ||
          CollectionOperation.addGuideline ||
          CollectionOperation.removeGuideline =>
            'You are offline. Connect to make this change.',
          _ => 'You are offline. Check your connection and try again.',
        };
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Your session expired. Sign in and try again.';
      }
      if (error.statusCode == 409 &&
          (operation == CollectionOperation.createCollection ||
              operation == CollectionOperation.updateCollection)) {
        return 'A collection with this name already exists.';
      }
      if (error.statusCode == 404) {
        return switch (operation) {
          CollectionOperation.addGuideline =>
            'This collection or guideline is no longer available. Refresh and try again.',
          CollectionOperation.removeGuideline =>
            'This saved guideline is no longer available. Refresh the collection.',
          _ => 'This collection is no longer available. Refresh your library.',
        };
      }
      if (error.statusCode >= 500) {
        return 'The server is unavailable. Please try again.';
      }
    }

    return switch (operation) {
      CollectionOperation.loadCollections =>
        'Your collections could not be loaded. Please try again.',
      CollectionOperation.loadCollection =>
        'This collection could not be loaded. Please try again.',
      CollectionOperation.loadMoreCollections =>
        'More collections could not be loaded. Please try again.',
      CollectionOperation.loadMoreGuidelines =>
        'More guidelines could not be loaded. Please try again.',
      CollectionOperation.createCollection =>
        'The collection could not be created. Please try again.',
      CollectionOperation.updateCollection =>
        'The collection could not be updated. Please try again.',
      CollectionOperation.deleteCollection =>
        'The collection could not be deleted. Please try again.',
      CollectionOperation.addGuideline =>
        'The guideline could not be saved. Please try again.',
      CollectionOperation.removeGuideline =>
        'The guideline could not be removed. Please try again.',
    };
  }
}
