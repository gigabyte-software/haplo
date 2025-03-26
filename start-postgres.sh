#!/bin/bash
set -e

# Initialize PostgreSQL if it's not already initialized
if [ ! -f /var/lib/postgresql/12/main/PG_VERSION ]; then
  echo "Initializing PostgreSQL database cluster..."
  sudo -u postgres /usr/lib/postgresql/12/bin/initdb -D /var/lib/postgresql/12/main
fi

# Start PostgreSQL
echo "Starting PostgreSQL..."
sudo service postgresql start

# Create required users and databases if they don't exist
sleep 2
if ! sudo -u postgres psql -tAc "\du" | grep -q "haplo"; then
  echo "Creating haplo database user..."
  sudo -u postgres psql -c "CREATE ROLE haplo WITH LOGIN CREATEDB PASSWORD 'haplo';"
fi

if ! sudo -u postgres psql -tAc "\list" | grep -q "haplo_development"; then
  echo "Creating haplo_development database..."
  sudo -u postgres psql -c "CREATE DATABASE haplo_development OWNER haplo ENCODING 'UTF8' TEMPLATE template0;"
fi

# Keep container running
tail -f /dev/null 