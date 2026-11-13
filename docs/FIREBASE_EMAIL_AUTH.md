# Firebase email code authentication

The Flutter app requests a six-digit email code from FastAPI for both account creation and login. The backend keeps a keyed digest in Redis for ten minutes and exchanges a valid code for a Firebase custom token. Flutter signs in with that token and sends its Firebase ID token to the FastAPI API. The backend verifies the ID token and maps the Firebase UID to its local user row.

Configure a Firebase project with Authentication enabled, create an Android, iOS, or web app as needed, and set Flutter build defines `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, plus `FIREBASE_AUTH_DOMAIN` for web and `FIREBASE_STORAGE_BUCKET` if storage is used. These are Firebase client settings, not service account secrets. Use the platform-specific app ID for each build.

Set backend environment variables from `.env.example`: `AUTH_PROVIDER=firebase`, `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON` (the full JSON of a service account allowed to mint custom tokens), a random `OTP_HMAC_SECRET`, and SMTP host, port, username, password, and sender. Keep these server-side. Configure `API_BASE_URL` in Flutter to reach FastAPI from each device. Redis must be available. Firebase is the default API authentication provider and fails closed until its backend credentials are configured.

Codes expire in ten minutes and allow five verification attempts. Firebase and the email provider may enforce their own quotas. Account creation and login have no trial period or account use limit.
