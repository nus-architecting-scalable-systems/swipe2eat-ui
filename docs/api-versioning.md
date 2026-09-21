# API v1 routing

Every public route is `/{service}/api/v1/{resource}`. The service prefix is used for ALB routing; the version and resource are defined by the backend. Trailing slashes are accepted by backend clients.

| Service | Public path | Direct service path (default servlet context) |
| --- | --- | --- |
| User | /user/api/v1/users | /user/api/v1/users |
| Food | /food/api/v1/foods | /food/api/v1/foods |
| User preferences | /preference/api/v1/users | /preference/api/v1/users |
| Dietary | /preference/api/v1/dietary | /preference/api/v1/dietary |

The service prefix selects the ALB target group; the version and resource segments are owned by the service. No route repeats the service name.

## Configuration and rollout

- For food-service and user-service, SERVICES_BASE_URL is the gateway origin, for example https://dev.keiyam.me. For direct preference-service access, include its context: http://localhost:8080/preference.
- In preference-service, FOOD_SERVICE_URL and USER_SERVICE_URL are service roots. Direct URLs must include /food or /user, respectively (for example http://localhost:8080/food). The default internal URLs now include those contexts. When using the gateway, use its origin without a context or /api/v1. Existing deployment environment overrides must follow this rule; changing YAML defaults does not replace overrides.
- Flutter API_BASE_URL is the gateway origin, without /api/v1. All application calls use the resource URLs in ApiConfig.
- The ALB forwards `/user/*`, `/preference/*`, and `/food/*` to the corresponding target groups without rewriting the path.
- Deploy the backend services before the updated UI. Existing installed clients using the old routes need a separate compatibility plan.

## Verification

Run the affected client and controller tests in each backend with ./gradlew test. Run flutter test in swipe2eat-ui. The HTTP client regression tests assert actual outgoing request paths, including internal service contexts and trailing-slash handling. Dietary routing tests exercise both canonical and compatibility paths.
