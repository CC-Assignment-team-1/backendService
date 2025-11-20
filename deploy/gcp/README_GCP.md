# Deploy backendService to GCP Compute Engine (cheap instance)

This guide uses a simple GCE VM (e2-micro) and Google Secret Manager for a secure credential flow.

High-level approach

1. Store your AWS credentials JSON in Google Secret Manager as a single JSON payload with keys: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `DYNAMODB_TABLE`.
2. Create a GCE service account with permission `roles/secretmanager.secretAccessor` and attach it to the VM.
3. Use the `deploy/gcp/startup-script.sh` as the VM Startup script; it will fetch the secret specified in metadata (key `secret-name`) and write it to `/opt/backendService/.env` with secure permissions.
4. The script clones the repo, installs dependencies, and configures Gunicorn + Nginx.

Quick steps

1. Add the secret via gcloud (or the console):

```bash
# Make a small JSON payload
cat <<EOF > aws_secret_payload.json
{
  "AWS_ACCESS_KEY_ID": "AKIA..",
  "AWS_SECRET_ACCESS_KEY": "abc..",
  "AWS_REGION": "us-east-1",
  "DYNAMODB_TABLE": "my-sample-table"
}
EOF

# Create or update Secret Manager
gcloud secrets create aws-backend-creds --replication-policy="automatic"
# OR if it exists, add versions
gcloud secrets versions add aws-backend-creds --data-file=aws_secret_payload.json
```

2. Create a service account for the VM with the `Secret Manager Secret Accessor` role

```bash
gcloud iam service-accounts create vm-secrets-sa --display-name "VM Secrets"
# give required access
gcloud projects add-iam-policy-binding $PROJECT --member serviceAccount:vm-secrets-sa@$PROJECT.iam.gserviceaccount.com --role roles/secretmanager.secretAccessor
```

3. Create a GCE instance with `deploy/gcp/startup-script.sh` as user-data:

```bash
gcloud compute instances create backend-service --zone us-central1-a --machine-type e2-micro --service-account vm-secrets-sa@$PROJECT.iam.gserviceaccount.com --metadata secret-name=aws-backend-creds --metadata-from-file startup-script=deploy/gcp/startup-script.sh
```

4. Open the VM’s public IP in a browser — Nginx will route to Gunicorn to serve the app.

Security notes

- This avoids embedding secrets in the VM image or user-data; secrets are retrieved from Secret Manager by the VM's service account.
- Make sure the service account attached to your GCE instance has the least privilege needed (Secret accessor only). Do not use full project scopes if not required.

Clutter reduction

- The `deploy/` folder contains both EC2 and GCP examples. If you prefer only GCP, move the EC2 scripts to `deploy/legacy/` (I can do this change for you)."