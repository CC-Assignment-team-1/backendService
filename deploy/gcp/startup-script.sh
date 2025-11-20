#!/usr/bin/env bash
# Streamlined startup script for GCE: clones repo, installs requirements, and starts the app with gunicorn behind nginx.

set -euxo pipefail

# Variables
GIT_REPO="https://github.com/CC-Assignment-team-1/backendService.git"
BRANCH="main"
APP_DIR="/opt/backendService"
APP_USER="root"  # Updated to root to avoid invalid user errors
PORT=8000

# Detect package manager
if [ -f /etc/debian_version ]; then
  PKGMGR="apt-get"
else
  PKGMGR="yum"
fi

# Update and install required packages
sudo $PKGMGR update -y
sudo $PKGMGR install -y git python3 python3-venv nginx

# Clone the repository
sudo mkdir -p $APP_DIR
sudo chown $APP_USER:$APP_USER $APP_DIR  # Ensure ownership is set to the correct user
if [ ! -d "$APP_DIR/.git" ]; then
  sudo -u $APP_USER git clone --branch $BRANCH $GIT_REPO $APP_DIR
else
  sudo -u $APP_USER git -C $APP_DIR pull
fi

# Set up Python virtual environment and install dependencies
sudo -u $APP_USER python3 -m venv $APP_DIR/.venv
sudo -u $APP_USER $APP_DIR/.venv/bin/pip install --upgrade pip
sudo -u $APP_USER $APP_DIR/.venv/bin/pip install -r $APP_DIR/requirements.txt

# Ensure Gunicorn is installed in the virtual environment
sudo -u $APP_USER $APP_DIR/.venv/bin/pip install gunicorn

# Define the host variable for Nginx configuration
host="localhost"  # Replace with the actual host if needed

# Define the remote_addr variable for Nginx configuration
remote_addr="127.0.0.1"  # Replace with the actual remote address if needed

# Define the proxy_add_x_forwarded_for variable for Nginx configuration
proxy_add_x_forwarded_for="$remote_addr"  # Use the remote address as the forwarded address

# Define the scheme variable for Nginx configuration
scheme="http"  # Default to HTTP; update if HTTPS is required

# Check if the port is available
if sudo lsof -i :$PORT; then
  echo "Port $PORT is already in use. Please choose a different port or stop the conflicting service."
  exit 1
fi

# Validate permissions for the APP_USER
if ! id -u $APP_USER > /dev/null 2>&1; then
  echo "User $APP_USER does not exist. Please create the user or update the APP_USER variable."
  exit 1
fi

# Create systemd service for Gunicorn
cat <<EOF | sudo tee /etc/systemd/system/backendservice.service
[Unit]
Description=Gunicorn instance to serve backendService
After=network.target

[Service]
User=$APP_USER
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/.venv/bin"
ExecStart=$APP_DIR/.venv/bin/gunicorn --workers 2 --bind 127.0.0.1:$PORT app:app

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the Gunicorn service
sudo systemctl daemon-reload
sudo systemctl enable --now backendservice.service

# Configure Nginx as a reverse proxy
cat <<EOF | sudo tee /etc/nginx/sites-available/backendservice
server {
    listen 80;
    server_name localhost;  # Updated from _ to localhost to avoid conflicts

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Disable the default Nginx configuration
if [ -f /etc/nginx/sites-enabled/default ]; then
  sudo rm /etc/nginx/sites-enabled/default
fi

# Ensure the custom Nginx configuration is enabled
sudo ln -sf /etc/nginx/sites-available/backendservice /etc/nginx/sites-enabled/

# Restart Nginx to apply changes
sudo systemctl restart nginx
