# cliniccare-releases

Public update feed for the ClinicCare tablet app. It holds **only** `latest.json` and, as GitHub Release assets, the signed APKs. No source code lives here (that stays in the private `cliniccare` repo).

The app's Settings → "Check for updates" fetches:

    https://raw.githubusercontent.com/manddar/cliniccare-releases/main/latest.json

and, if `build` is newer than the installed build, downloads `apk_url`, checks `sha256`, and opens the Android installer.

## One-time setup

1. Create an empty **public** GitHub repo named `cliniccare-releases`.
2. Edit `config.env`: set `OWNER` (already `manddar`).
3. From this folder:

       git remote add origin git@github.com:manddar/cliniccare-releases.git
       git add . && git commit -m "Initial feed" && git push -u origin main

## Publishing a release

1. In the app repo: bump `version:` in `pubspec.yaml`, update `CHANGELOG.md`, run `flutter build apk --release --target-platform android-arm64` (signed with the release keystore). **Do not use `--split-per-abi`**: it changes the APK's versionCode (arm64 becomes build+2000) and the in-app update check then never sees newer builds.
2. Write short release notes in a text file, e.g. `notes.txt`.
3. Here, run:

       ./scripts/release.sh ../cliniccare/build/app/outputs/flutter-apk/app-release.apk notes.txt

   It reads the version and DB schema from the app repo, copies the APK to `dist/cliniccare-<version>-<build>.apk`, computes SHA-256, and rewrites `latest.json`.
4. Upload the APK, then publish the manifest (the script prints these commands):

       gh release create v1.0.0 dist/cliniccare-1.0.0-1.apk --title "ClinicCare 1.0.0" --notes-file notes.txt
       git add latest.json && git commit -m "Release 1.0.0+1" && git push

   Upload the APK **before** pushing the manifest, so the feed never points at a missing file.

## latest.json fields

| Field | Meaning |
|---|---|
| `version`, `build` | Same as pubspec `X.Y.Z+BUILD`. The app compares `build` to its installed build number. |
| `schema_version` | Database schema in that release (informational; lets the app warn before a migrating update). |
| `min_supported_build` | Installed builds below this must update. Raise it only for breaking fixes. |
| `apk_url` | GitHub Release asset URL. |
| `sha256`, `size_bytes` | Verified by the app before installing. |
| `released_at`, `notes` | Shown in the update dialog. |

## Rules

- `build` must always increase; Android refuses to install a lower `versionCode`.
- Always sign with the same keystore, or the tablet rejects the update.
- Never edit or delete a published APK; ship a new build instead.
- Nothing patient-related ever goes in this repo.
