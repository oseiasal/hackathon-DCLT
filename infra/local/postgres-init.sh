#!/bin/sh
set -e

echo "Criando bancos de dados ngo_db e donation_db..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    SELECT 'CREATE DATABASE ngo_db'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ngo_db')\gexec

    SELECT 'CREATE DATABASE donation_db'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'donation_db')\gexec
EOSQL

echo "Aplicando schema inicial em ngo_db..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "ngo_db" -f /sql/ngo-init.sql

echo "Aplicando schema inicial em donation_db..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "donation_db" -f /sql/donation-init.sql

echo "Bancos inicializados com sucesso."
