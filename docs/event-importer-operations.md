# Event importer operations

The importer reads official event sources, validates and de-duplicates records,
and writes only `draft` events. It never publishes an event automatically.

## Schedule

- Frequent sources run every six hours.
- Daily sources run at 03:30 Asia/Bangkok (`20:30 UTC`).
- Scheduled writes are disabled unless the repository variable
  `EVENT_IMPORT_WRITE_ENABLED` is exactly `true`.
- Manual runs can choose a source group and remain dry-run by default.

GitHub schedules can start later than the requested minute during busy periods.
The deterministic event identity makes delayed or repeated runs safe.

## Source status

| Source | Group | Default | Safety behavior |
| --- | --- | --- | --- |
| TAT monthly calendar | daily | enabled | Structured dates and reviewed Thai calendar text |
| TAT Newsroom feature articles | frequent | enabled | Future articles become review-required drafts |
| TAT tourism product calendar API | frequent | disabled | Fallback/demo responses are rejected |

The official Thailand government events page, main Tourism Thailand events
page, and initial provincial sites were evaluated but are not enabled. They
currently require anti-bot browser challenges, expose invalid TLS chains, or do
not provide a stable public event API. The importer must not bypass those
controls. Add them only after the owner provides an API, RSS feed, or explicit
machine-access permission and a parser fixture has been reviewed.

## Google Cloud authentication

Use Workload Identity Federation instead of a service-account key:

```powershell
.\scripts\setup-github-oidc.ps1
```

The script prints the values to add under GitHub repository Settings > Secrets
and variables > Actions > Variables:

- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_EVENT_IMPORTER_SERVICE_ACCOUNT`
- `EVENT_IMPORT_WRITE_ENABLED`

Keep `EVENT_IMPORT_WRITE_ENABLED=false` during the observation period. After at
least three successful dry runs, set it to `true`. The importer service account
uses the project-level `roles/datastore.user` role because Firestore IAM does
not support collection-scoped write roles. Firestore Security Rules still deny
client access to importer operational collections.

## Local commands

```powershell
npm --prefix event_importer run dry-run -- --group all --limit 50
$env:FIREBASE_PROJECT_ID="thai-fabric-check-in-app"
npm --prefix event_importer run import -- --group daily --limit 50
```

Application Default Credentials are required for a local write run:

```powershell
gcloud auth application-default login
```

## Quality gates

- A source is retried three times for network failures.
- A source failure does not stop other sources.
- Runs are rejected when every selected source fails.
- Runs are rejected when more than 20% of attempted records are invalid.
- Upstream fallback/demo payloads are not imported.
- Imported records always start as `draft`.
- Published or manually edited records are never overwritten.
- Raw snapshots expire after 60 days and are removed in bounded batches.

## Rollout

1. Leave scheduled writes disabled for at least three successful runs.
2. Review the uploaded `dry-run-output.json` artifacts.
3. Enable writes and review all imported drafts daily for seven days.
4. Enable additional source adapters only after parser fixtures and source terms
   have been reviewed.
