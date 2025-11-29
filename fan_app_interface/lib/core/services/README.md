Service utilities and DI notes

This folder will contain service bootstrap and registration helpers.

Recommended files:
- service_locator.dart (or injection.dart): initializes and registers singletons/factories
- analytics_service.dart, location_service.dart, notifications_service.dart

Keep services small and testable. Use an interface/abstract class per service to
allow mocking in tests.
