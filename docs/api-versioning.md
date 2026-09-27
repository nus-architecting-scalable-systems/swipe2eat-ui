# API v1 routing

Every public route is `/api/v1/{service}/{resource}`. The service segment is used for ALB routing; the version and remaining resource segments are defined by the backend.

| Service | Public and direct-service path |
| --- | --- |
| User | /api/v1/user |
| Food | /api/v1/food |
| User preferences | /api/v1/preference/users |
| Dietary | /api/v1/preference/dietary |

The service segment after the version selects the ALB target group.

## Configuration and rollout

- API_BASE_URL, SERVICES_BASE_URL, FOOD_SERVICE_URL, and USER_SERVICE_URL are bare origins, for example https://dev.keiyam.me or http://localhost:8080. Clients append their `/api/v1/<service>` path themselves.
- Flutter API_BASE_URL is the gateway origin, without /api/v1. All application calls use the resource URLs in ApiConfig.
- The ALB forwards `/api/v1/user*`, `/api/v1/preference*`, and `/api/v1/food*` to the corresponding target groups without rewriting the path.
- Deploy all three backend services before the updated UI. Existing installed clients using old routes need a compatibility plan.

## Verification

Run the affected client and controller tests in each backend with ./gradlew test. Run flutter test in swipe2eat-ui. The HTTP client regression tests assert actual outgoing request paths.
