#!/bin/bash
set -e

echo "Starting Haplo setup..."

# Make sure PostgreSQL directories have proper ownership
echo "Ensuring proper PostgreSQL ownership..."
sudo chown -R postgres:postgres /etc/postgresql
sudo chown -R postgres:postgres /var/lib/postgresql
sudo mkdir -p /var/run/postgresql
sudo chown -R postgres:postgres /var/run/postgresql
sudo chmod 2777 /var/run/postgresql

# Initialize PostgreSQL if it's not already initialized
if [ ! -f /var/lib/postgresql/12/main/PG_VERSION ]; then
  echo "Initializing PostgreSQL database cluster..."
  sudo -u postgres /usr/lib/postgresql/12/bin/initdb -D /var/lib/postgresql/12/main
fi

# Start PostgreSQL
echo "Starting PostgreSQL..."
sudo -u postgres service postgresql start

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
max_attempts=10
attempts=0
until sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1 || [ $attempts -eq $max_attempts ]; do
  attempts=$((attempts+1))
  echo "Waiting for PostgreSQL to start ($attempts/$max_attempts)..."
  sleep 1
done

if [ $attempts -eq $max_attempts ]; then
  echo "ERROR: PostgreSQL failed to start within the allocated time."
  exit 1
fi

# Create database role and databases if needed
echo "Setting up PostgreSQL role..."
if ! sudo -u postgres psql -tAc "\\du" | grep -q "haplo"; then
  sudo -u postgres psql -c "CREATE ROLE haplo WITH LOGIN CREATEDB PASSWORD 'haplo';"
fi

echo "Setting up PostgreSQL databases..."
# Create haplo_development database if it doesn't exist
if ! sudo -u postgres psql -tAc "\\list" | grep -q "haplo_development"; then
  echo "Creating database: haplo_development"
  sudo -u postgres psql -c "CREATE DATABASE haplo_development OWNER haplo ENCODING 'UTF8' TEMPLATE template0;"
fi

# Create khq_development database if it doesn't exist
if ! sudo -u postgres psql -tAc "\\list" | grep -q "khq_development"; then
  echo "Creating database: khq_development"
  sudo -u postgres psql -c "CREATE DATABASE khq_development OWNER haplo ENCODING 'UTF8' TEMPLATE template0;"
fi

# Clone the repository if it doesn't exist
if [ ! -d /home/haplo/haplo ]; then
  echo "Cloning custom Haplo repository..."
  cd /home/haplo
  
  # Use the specific repository and branch
  HAPLO_REPO="https://github.com/gigabyte-software/haplo.git"
  HAPLO_BRANCH="ek"
  
  sudo -u haplo git clone $HAPLO_REPO
  cd haplo
  sudo -u haplo git checkout $HAPLO_BRANCH
else
  echo "Haplo repository already exists, updating to latest..."
  cd /home/haplo/haplo
  sudo -u haplo git pull
fi

# Run the Haplo installation script
echo "Setting up Haplo application..."
cd /home/haplo
sudo -u haplo /usr/local/bin/haplo-install.sh docker

# Keep the container running
echo "Haplo setup complete. Container is now running."
tail -f /dev/null 