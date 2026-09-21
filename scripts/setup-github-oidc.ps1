param(
  [string]$ProjectId = "thai-fabric-check-in-app",
  [string]$Repository = "peeax/ThaiFabricCheckinApp",
  [string]$PoolId = "github-actions",
  [string]$ProviderId = "thai-fabric-checkin",
  [string]$ServiceAccountId = "event-importer"
)

$ErrorActionPreference = "Stop"
$serviceAccount = "$ServiceAccountId@$ProjectId.iam.gserviceaccount.com"
$projectNumber = gcloud projects describe $ProjectId --format="value(projectNumber)"
if (-not $projectNumber) {
  throw "Unable to resolve the project number for $ProjectId"
}

gcloud services enable iamcredentials.googleapis.com sts.googleapis.com --project=$ProjectId

gcloud iam service-accounts describe $serviceAccount --project=$ProjectId 2>$null
if ($LASTEXITCODE -ne 0) {
  gcloud iam service-accounts create $ServiceAccountId `
    --project=$ProjectId `
    --display-name="Aewmai event importer"
}

gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$serviceAccount" `
  --role="roles/datastore.user" `
  --condition=None

gcloud iam workload-identity-pools describe $PoolId `
  --project=$ProjectId `
  --location=global 2>$null
if ($LASTEXITCODE -ne 0) {
  gcloud iam workload-identity-pools create $PoolId `
    --project=$ProjectId `
    --location=global `
    --display-name="GitHub Actions"
}

gcloud iam workload-identity-pools providers describe $ProviderId `
  --project=$ProjectId `
  --location=global `
  --workload-identity-pool=$PoolId 2>$null
if ($LASTEXITCODE -ne 0) {
  gcloud iam workload-identity-pools providers create-oidc $ProviderId `
    --project=$ProjectId `
    --location=global `
    --workload-identity-pool=$PoolId `
    --display-name="ThaiFabricCheckin GitHub" `
    --issuer-uri="https://token.actions.githubusercontent.com" `
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" `
    --attribute-condition="assertion.repository=='$Repository'"
}

$poolName = "projects/$projectNumber/locations/global/workloadIdentityPools/$PoolId"
gcloud iam service-accounts add-iam-policy-binding $serviceAccount `
  --project=$ProjectId `
  --role="roles/iam.workloadIdentityUser" `
  --member="principalSet://iam.googleapis.com/$poolName/attribute.repository/$Repository"

$providerName = "$poolName/providers/$ProviderId"
Write-Host ""
Write-Host "Add these GitHub repository variables:"
Write-Host "GCP_WORKLOAD_IDENTITY_PROVIDER=$providerName"
Write-Host "GCP_EVENT_IMPORTER_SERVICE_ACCOUNT=$serviceAccount"
Write-Host "EVENT_IMPORT_WRITE_ENABLED=false"
