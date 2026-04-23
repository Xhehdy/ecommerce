/// Search feature barrel — re-exports the search screen and models.
///
/// The search feature was originally developed under `features/marketplace/`.
/// This barrel provides the structural separation called out in the build spec
/// without breaking existing import chains.
library search;

export '../marketplace/presentation/screens/search_screen.dart';
export '../marketplace/data/models/search_models.dart';
