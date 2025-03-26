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

# Double check that Haplo directories have correct permissions
echo "Checking Haplo directory permissions..."
sudo chown -R haplo:haplo /haplo
sudo chown -R postgres:postgres /haplo/textidx
sudo chown -R haplo:haplo /opt/haplo

# Initialize PostgreSQL if it's not already initialized
if [ ! -f /var/lib/postgresql/12/main/PG_VERSION ]; then
  echo "Initializing PostgreSQL database cluster..."
  sudo -u postgres /usr/lib/postgresql/12/bin/initdb -D /var/lib/postgresql/12/main
fi

# Start PostgreSQL
echo "Starting PostgreSQL..."
sudo -u postgres pg_ctl -D /var/lib/postgresql/12/main -l /var/log/postgresql/postgresql-12-main.log start || {
  echo "Failed to start PostgreSQL with pg_ctl, checking logs:"
  cat /var/log/postgresql/postgresql-12-main.log || true
  echo "Trying alternative method to start PostgreSQL..."
  sudo -u postgres service postgresql start
}

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
max_attempts=30
attempts=0
until sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1 || [ $attempts -eq $max_attempts ]; do
  attempts=$((attempts+1))
  echo "Waiting for PostgreSQL to start ($attempts/$max_attempts)..."
  sleep 1
done

if [ $attempts -eq $max_attempts ]; then
  echo "ERROR: PostgreSQL failed to start within the allocated time."
  echo "Checking PostgreSQL logs:"
  cat /var/log/postgresql/postgresql-12-main.log || true
  echo "Will continue, but application might fail to start properly."
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

# Double check SSL certificates exist
echo "Checking SSL certificates..."
if [ ! -f /haplo/sslcerts/server.crt ] || [ ! -f /haplo/sslcerts/server.key ]; then
  echo "SSL certificates missing, regenerating..."
  mkdir -p /tmp/haplo-sslcerts
  cd /tmp/haplo-sslcerts
  openssl genrsa -out server.key 2048
  openssl req -new -batch -subj "/CN=haplo.local" -key server.key -out server.crt.csr
  openssl x509 -req -sha256 -days 3650 -in server.crt.csr -out server.crt -signkey server.key
  chmod 644 server.crt server.crt.csr && chmod 600 server.key
  sudo cp server.crt server.crt.csr server.key /haplo/sslcerts/
  sudo chown -R haplo:haplo /haplo/sslcerts
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

# Run the Haplo installation script with Docker-specific modifications
echo "Setting up Haplo application..."
cd /home/haplo
sudo -u haplo /usr/local/bin/haplo-install-docker.sh docker

# Run the database setup scripts if they exist
echo "Setting up database schema..."
cd /home/haplo/haplo
export KFRAMEWORK_ENV=development
if [ -f db/do_init_db.sh ]; then
  echo "Running database initialization script..."
  sudo -u haplo bash -c "cd /home/haplo/haplo && KFRAMEWORK_ENV=development bash db/do_init_db.sh"
fi

# Create Maven classpath if needed
if [ ! -f /home/haplo/haplo/target/classpath.txt ]; then
  echo "Generating Maven classpath..."
  cd /home/haplo/haplo
  sudo -u haplo mvn dependency:build-classpath -Dmdep.outputFile=target/classpath.txt
fi

# Start the application server
echo "Starting Haplo application server..."
cd /home/haplo/haplo
sudo -u haplo java -Djava.awt.headless=true -cp /home/haplo/haplo/target/haplo-3.20210923.0927.c6a8d17010.jar:/home/haplo/haplo/target/classes:/home/haplo/haplo/target/classpath.txt org.haplo.app.Server --debug --sslcert=/haplo/sslcerts/server.crt --sslkey=/haplo/sslcerts/server.key &

# Keep the container running
echo "Haplo setup complete. Container is now running."
tail -f /dev/null 