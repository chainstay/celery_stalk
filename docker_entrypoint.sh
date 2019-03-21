#!/bin/sh

set -e

if ["$RUN_AS_WORKER" !== ""]; then
  until PGPASSWORD=$POSTGRES_PASSWORD psql -h db -U "postgres" -c '\q'; do
    >&2 echo "Postgres is unavailable - sleeping"
    sleep 1
  done
  >&2 echo "Postgres is up!"
fi

if ["$RUN_AS_WORKER" !== ""]; then
  python /app/manage.py runserver 0.0.0.0:8000
else
  celery -A celery_stalk worker -l INFO
fi
