#!/usr/bin/env bash
# Cloud-init script for provisioning a cheap EC2 instance to run this Flask app.
# This script assumes the instance has Internet access and optionally an IAM role
# that allows reading DynamoDB. If you must use AWS credentials, put them in
# ~/.aws/credentials or in the .env file created below (not recommended).

set -euxo pipefail

# Configuration variables (set these when calling run-instances or edit here)
GIT_REPO="https://github.com/CC-Assignment-team-1/backendService.git"
BRANCH="main"
APP_DIR="/opt/backendService"
APP_USER="ec2-user"  # keep default for Amazon Linux / change to 'ubuntu' on Ubuntu
PORT=8000

# Prepare environment: update, install git, python3, nginx
if grep -qi "^NAME=.*amazon" /etc/os-release; then
  # Amazon Linux 2
  sudo yum update -y
  sudo yum install -y git python3 nginx
  PYTHON=python3
else
  # Debian/Ubuntu
  sudo apt-get update -y
  sudo apt-get install -y git python3 python3-venv python3-distutils nginx
  PYTHON=python3
fi

# Clone application
sudo mkdir -p $APP_DIR
sudo chown $APP_USER:$APP_USER $APP_DIR
sudo -u $APP_USER bash -lc "if [ ! -d \"$APP_DIR/.git\" ]; then git clone --branch $BRANCH $GIT_REPO $APP_DIR; else cd $APP_DIR && git pull; fi"

# Create virtualenv and install requirements
sudo -u $APP_USER $PYTHON -m venv $APP_DIR/.venv
sudo -u $APP_USER $APP_DIR/.venv/bin/pip install --upgrade pip
sudo -u $APP_USER $APP_DIR/.venv/bin/pip install -r $APP_DIR/requirements.txt

# Create .env for app (environmental variables can be embedded here or set in IAM)
# Create .env for app (environmental variables can be embedded here)
# If you passed AWS credentials in the user-data, they will be written to the .env file.
cat <<'EOF' | sudo tee $APP_DIR/.env
# Place any overrides here or pass values via instance profile
# DYNAMODB_TABLE=my-sample-table
# AWS_REGION=us-east-1
EOF

# If the user-data includes AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY placeholders they will be
# present as environment variables when this script runs. Write them into .env for boto3.
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
  sudo tee -a $APP_DIR/.env > /dev/null <<EOF
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
EOF
  echo "Wrote credentials to $APP_DIR/.env"
else
  echo "No AWS credentials found in user-data, relying on IAM instance profile or other config"
fi
sudo chown $APP_USER:$APP_USER $APP_DIR/.env

# Systemd service for gunicorn
sudo tee /etc/systemd/system/backendservice.service > /dev/null <<EOF
[Unit]
Description=Gunicorn instance to serve backendService
After=network.target

[Service]
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/.venv/bin"
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/.venv/bin/gunicorn --workers 2 --bind 127.0.0.1:$PORT app:app

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
sudo systemctl daemon-reload
sudo systemctl enable --now backendservice.service

# Configure Nginx as a reverse proxy to Gunicorn
sudo rm -f /etc/nginx/conf.d/default.conf || true
sudo tee /etc/nginx/conf.d/backendservice.conf > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
sudo systemctl enable --now nginx

# Ensure firewall (selinux / iptables) allow 80 — cloud provider manages this in security group

EOF