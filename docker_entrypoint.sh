#!/bin/sh

set -e

host="$1"

until PGPASSWORD=$POSTGRES_PASSWORD psql -h "$host" -U "postgres" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up!"

python /app/manage.py runserver 0.0.0.0:8000
