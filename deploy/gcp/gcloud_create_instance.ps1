# PowerShell helper to create a GCE VM and pass secret name via metadata.
# Usage: configure the variables below, then run from a client with gcloud installed and authenticated

$Project = 'my-gcp-project'
$Zone = 'us-central1-a'
$InstanceName = 'backend-service'
$MachineType = 'e2-micro' # cheap
$ImageFamily = 'debian-12'
$ImageProject = 'debian-cloud'
$ServiceAccount = 'my-vm-sa@my-gcp-project.iam.gserviceaccount.com' # VM service account
$SecretName = 'aws-backend-creds' # name of secret in Secret Manager
$StartupScript = 'deploy/gcp/startup-script.sh'

# Optional: specify your local service account key to create the secret. Otherwise create the secret in console.
$ServiceKey = '' # path to service account json if you need to authenticate gcloud on local machine

if ($ServiceKey) {
    gcloud auth activate-service-account --key-file=$ServiceKey
}

# Ensure your project is selected
gcloud config set project $Project

# If local secret file is present (a JSON with AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, DYNAMODB_TABLE)
$LocalAwsSecretFile = '.\aws_secret_payload.json'
if (Test-Path $LocalAwsSecretFile) {
    # Create a secret in Secret Manager and add the payload
    gcloud secrets create $SecretName --replication-policy="automatic" || true
    gcloud secrets versions add $SecretName --data-file=$LocalAwsSecretFile
}

# Create GCE instance with service account that has roles/secretmanager.secretAccessor
gcloud compute instances create $InstanceName \
  --project $Project \
  --zone $Zone \
  --machine-type $MachineType \
  --image-family $ImageFamily \
  --image-project $ImageProject \
  --service-account $ServiceAccount \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --metadata secret-name=$SecretName \
  --metadata-from-file startup-script=$StartupScript

Write-Host "Instance creation requested: $InstanceName in $Zone"