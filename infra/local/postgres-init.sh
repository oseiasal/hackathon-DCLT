#!/bin/sh
set -e

echo "Criando bancos de dados ngo_db e donation_db..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    SELECT 'CREATE DATABASE ngo_db'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ngo_db')\gexec

    SELECT 'CREATE DATABASE donation_db'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'donation_db')\gexec
EOSQL

echo "Bancos ngo_db e donation_db prontos (schemas gerenciados via processos one-off de migration)."
