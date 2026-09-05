# iconstruct

Flutter app for the iConstruct authentication and onboarding flow.

## Email OTP Setup

This repo uses a custom 6-digit email OTP flow backed by Firebase Functions, Firestore, and Nodemailer SMTP.

### 1. Enable Firebase services

1. In the Firebase console, enable Authentication with the Email/Password provider.
2. Create a Firestore database in Native mode.
3. Configure the Functions backend parameters and secret for SMTP mail delivery:
	- `EMAIL_FROM`
	- `SMTP_HOST`
	- `SMTP_PORT`
	- `SMTP_USER`
	- `SMTP_PASS`

Example Firebase CLI setup:

```bash
firebase functions:params:set EMAIL_FROM="you@example.com" SMTP_HOST="smtp.gmail.com" SMTP_PORT="465" SMTP_USER="you@example.com"
firebase functions:secrets:set SMTP_PASS
firebase deploy --only functions
```

If OTP sending fails immediately, check the deployed Functions logs and confirm all five values above are configured. The callable now returns a direct configuration error when any SMTP value is missing.

### 2. Run the app

```bash
flutter pub get
flutter run
```

The app now sends the 6-digit OTP when the user starts registration, opens a verification modal, stores the OTP in the `email_otp` collection for 5 minutes, emails the code through Nodemailer SMTP, and requires OTP verification before the registration request is allowed to complete.

## Materials API (Firestore-driven)

This repo also includes an HTTP API (Firebase Functions + Express) for dynamic project categories and material recommendations.

### Firestore collections

- `projects/{projectId}`
	- `name`: display name (e.g. `Bathroom Renovation`)
	- `slug`: stable lowercase key used for lookup (e.g. `bathroom`)
	- `name_lower`: lowercase name for fallback lookup (e.g. `bathroom renovation`)

- `categories/{categoryId}`
	- `project_id`: reference to the owning project doc id
	- `name`: display name (e.g. `Floor Surface`)
	- `type`: `floor` or `wall`
	- `name_lower`: lowercase name (e.g. `floor surface`)
	- `order`: number for sorting

- `materials/{materialId}`
	- `category_id`: reference to the owning category doc id
	- `name`
	- `description`
	- `is_recommended`: boolean
	- `image_url`: optional (e.g. Firebase Storage URL)

### HTTP endpoints

- `GET /api/categories?project=<project>`
	- Looks up `projects` by `slug` first, then `name_lower`.
	- Returns `{ project_id, categories: [{ id, name }] }`.

- `GET /api/materials?categoryId=<id>` or `GET /api/materials?category=<name>&project=<project>`
	- Returns `{ category, category_id, recommended, alternatives }`.
	- `recommended` is capped at 3 items.

Deployed URL format (default): `https://us-central1-<firebase-project-id>.cloudfunctions.net/api`
