# PowerShell script to automate GCP VM creation and deployment

# Variables
$GCP_INSTANCE_NAME = "flask-backend-instance"
$GCP_ZONE = "us-central1-a"
$GCP_MACHINE_TYPE = "e2-small"  # Updated from e2-micro to e2-small for better performance
$GCP_IMAGE_FAMILY = "ubuntu-2204-lts"
$GCP_IMAGE_PROJECT = "ubuntu-os-cloud"
$STARTUP_SCRIPT_PATH = "C:\Users\prish\Desktop\CloudOrgAssign\backendService\deploy\gcp\startup-script.sh"

# Check if gcloud CLI is installed
if (-not (Get-Command "gcloud" -ErrorAction SilentlyContinue)) {
    Write-Error "gcloud CLI is not installed. Please install it from https://cloud.google.com/sdk/docs/install."
    exit 1
}

# Check if the instance already exists
Write-Host "Checking if the instance already exists..."
$InstanceExists = & gcloud compute instances list --filter="name=$GCP_INSTANCE_NAME AND zone:($GCP_ZONE)" --format="value(name)"

if ($InstanceExists) {
    Write-Host "Instance $GCP_INSTANCE_NAME already exists. Deleting the existing instance..."
    $DeleteResult = & gcloud compute instances delete $GCP_INSTANCE_NAME --zone=$GCP_ZONE --quiet

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to delete the existing instance. It may not exist. Proceeding to create a new instance."
    } else {
        Write-Host "Existing instance deleted successfully."
    }
}

# Create the GCP Compute Engine instance
Write-Host "Creating GCP Compute Engine instance..."
& gcloud compute instances create $GCP_INSTANCE_NAME `
    --machine-type=$GCP_MACHINE_TYPE `
    --image-family=$GCP_IMAGE_FAMILY `
    --image-project=$GCP_IMAGE_PROJECT `
    --metadata-from-file startup-script=$STARTUP_SCRIPT_PATH `
    --tags=http-server `
    --scopes=https://www.googleapis.com/auth/cloud-platform `
    --zone=$GCP_ZONE `
    --boot-disk-size=10GB

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create the GCP Compute Engine instance."
    exit 1
}

Write-Host "GCP Compute Engine instance created successfully."

# Create a firewall rule to allow HTTP traffic
Write-Host "Creating firewall rule to allow HTTP traffic..."
& gcloud compute firewall-rules create allow-http `
    --allow tcp:80 `
    --target-tags=http-server `
    --description="Allow HTTP traffic" --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Firewall rule may already exist. Skipping creation."
} else {
    Write-Host "Firewall rule created successfully."
}

# Retrieve the external IP of the instance
$ExternalIP = & gcloud compute instances describe $GCP_INSTANCE_NAME --zone=$GCP_ZONE --format="get(networkInterfaces[0].accessConfigs[0].natIP)"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to retrieve the external IP of the instance."
    exit 1
}

Write-Host "Deployment successful! Access your application at http://$ExternalIP"