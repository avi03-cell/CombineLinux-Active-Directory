#!/bin/bash
set -euxo pipefail

# Log user-data output for debugging
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

export DEBIAN_FRONTEND=noninteractive

##########################################################
# Update Ubuntu
##########################################################

apt-get update -y
apt-get upgrade -y

##########################################################
# Install SSM Agent
##########################################################

snap install amazon-ssm-agent --classic

systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service

systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

##########################################################
# Install Packages
##########################################################

apt-get install -y \
    realmd \
    sssd \
    sssd-tools \
    libnss-sss \
    libpam-sss \
    adcli \
    krb5-user \
    samba-common-bin \
    packagekit \
    ldap-utils

##########################################################
# Enable Services
##########################################################

systemctl enable nginx
systemctl start nginx

systemctl enable postgresql
systemctl start postgresql

##########################################################
# Create Dummy Website
##########################################################

cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html>
<head>
<title>${website_title}</title>

<style>

body{
    background:#f4f4f4;
    font-family:Arial;
    text-align:center;
    margin-top:80px;
}

.container{
    width:700px;
    margin:auto;
    background:white;
    padding:40px;
    border-radius:10px;
    box-shadow:0 0 20px rgba(0,0,0,.2);
}

h1{
    color:#1f4e79;
}

p{
    font-size:20px;
}

</style>

</head>

<body>

<div class="container">

<h1>${website_heading}</h1>

<p>Nginx is running successfully.</p>

<p>This EC2 instance is inside a <b>Private Subnet</b>.</p>

<p>Traffic reaches this server through an <b>Application Load Balancer</b>.</p>

<p>Provisioned completely using Terraform.</p>

</div>

</body>

</html>

HTML

##########################################################
# ALB Health Check Page
##########################################################

echo "healthy" > /var/www/html/health

systemctl restart nginx

##########################################################
# Wait for PostgreSQL
##########################################################

until pg_isready
do
    sleep 2
done

##########################################################
# PostgreSQL Configuration
##########################################################

PG_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)

sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" \
/etc/postgresql/$PG_VERSION/main/postgresql.conf

cat <<PGHBA >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf

host    all             all             10.0.0.0/16            scram-sha-256

PGHBA

systemctl restart postgresql

##########################################################
# Create Database & User
##########################################################

sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL

CREATE USER ${postgres_user}
WITH PASSWORD '${postgres_password}';

CREATE DATABASE ${postgres_db}
OWNER ${postgres_user};

GRANT ALL PRIVILEGES
ON DATABASE ${postgres_db}
TO ${postgres_user};

SQL

##########################################################
# Create Sample Table
##########################################################

sudo -u postgres psql -d ${postgres_db} -v ON_ERROR_STOP=1 <<SQL

CREATE TABLE IF NOT EXISTS inventory (

    id SERIAL PRIMARY KEY,

    item_name VARCHAR(100),

    quantity INT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);

INSERT INTO inventory(item_name, quantity)

VALUES

('Cloud Optimized Widget',150),

('Terraform Blueprint',42),

('High Availability Gadget',89);

GRANT ALL PRIVILEGES
ON ALL TABLES IN SCHEMA public
TO ${postgres_user};

GRANT ALL PRIVILEGES
ON ALL SEQUENCES IN SCHEMA public
TO ${postgres_user};

SQL

##########################################################
# Finished
##########################################################

echo "Bootstrap completed successfully."