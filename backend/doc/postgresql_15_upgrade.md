# Upgrading Postgres 14 -> 15 on Ubuntu 22.04

To find the installed versions:
dpkg --get-selections | grep postgres

List the clusters that are on your machine:
pg_lsclusters

PostgreSQL 15 package is not available in the default package repository

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/pgdg.asc &>/dev/null
sudo apt-get update
sudo apt-get install libpq-dev postgresql-15 postgresql-client-15

Stop Postgres
sudo service postgresql stop

Rename default clusted
sudo pg_renamecluster 15 main main_pristine

Upgrade cluster
sudo pg_upgradecluster 14 main

Start Postgres
sudo service postgresql start

If all is well, drop the old cluster
sudo pg_dropcluster 14 main --stop
sudo pg_dropcluster 15 main_pristine --stop
