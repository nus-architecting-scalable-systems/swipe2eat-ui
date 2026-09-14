# API v1 routing

All clients append /api/v1 exactly once. Configured base URLs must omit that version prefix. Trailing slashes are accepted by backend clients.

| Service | Public path | Direct service path (default servlet context) |
| --- | --- | --- |
| User | /api/v1/user | /user/api/v1/user |
| Food | /api/v1/food | /food/api/v1/food |
| Preferences | /api/v1/preference | /preference/api/v1/preference |
| Dietary | /api/v1/preference/dietary | /preference/api/v1/preference/dietary |

Preference service also retains /preference/api/v1/dietary as a compatibility alias. The new canonical dietary path matches the Flutter client.

## Configuration and rollout

- For food-service and user-service, SERVICES_BASE_URL is the gateway origin, for example https://dev.keiyam.me. For direct preference-service access, include its context: http://localhost:8080/preference.
- In preference-service, FOOD_SERVICE_URL and USER_SERVICE_URL are service roots. Direct URLs must include /food or /user, respectively (for example http://localhost:8080/food). The default internal URLs now include those contexts. When using the gateway, use its origin without a context or /api/v1. Existing deployment environment overrides must follow this rule; changing YAML defaults does not replace overrides.
- Flutter API_BASE_URL is the gateway origin, without /api/v1. All application calls use the resource URLs in ApiConfig.
- The gateway must forward the public paths above to the corresponding direct service paths. Its configuration is outside these repositories and has not been verified here. Confirm both route selection and path rewriting before deploying.
- Deploy the matching backend routing changes before the updated UI. Keep any existing gateway aliases used by older installed clients during the migration. This change does not add unversioned controller aliases or remove existing gateway aliases.

## Verification

Run the affected client and controller tests in each backend with ./gradlew test. Run flutter test in swipe2eat-ui. The HTTP client regression tests assert actual outgoing request paths, including internal service contexts and trailing-slash handling. Dietary routing tests exercise both canonical and compatibility paths.
