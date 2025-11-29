Map feature

This feature is responsible for the in-app map experience. It should follow
the feature-first + clean-architecture layout:

Structure suggestions:
- data/
  - models/: data-transfer models and JSON (POI models, route models)
  - datasources/: network/local sources (APIs, local DB, sensors)
  - repositories/: concrete implementations that map data models to domain
- domain/
  - entities/: plain domain entities (POI, Route, Category)
  - usecases/: application-specific operations (getPois, searchPoi)
  - repositories/: repository contracts/interfaces used by domain
- presentation/
  - pages/: top-level pages/screens (MapPage)
  - widgets/: small reusable widgets local to the feature (POI marker, chip)
  - controllers/: state holders (ViewModel/Bloc) for the presentation layer

Keep implementation details inside the feature. Expose only domain contracts
to the rest of the app.
