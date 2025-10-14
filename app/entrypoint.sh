#!/usr/bin/env bash
set -e

# Check if set, if not use default
ENVIRONMENT=${ENVIRONMENT:-production}

# Wait for Postgres
echo "Waiting for postgres to connect ..."
while ! nc -z truck_signs_postgres 5432; do
  sleep 0.1
done
echo "PostgreSQL is active"

# Run migration and collect static file
python manage.py makemigrations
python manage.py migrate
python manage.py collectstatic --noinput
echo "Postgresql migrations finished"

# Credential check, stop early if something is missing
if [ -z "$DJANGO_SUPERUSER_USERNAME" ] || [ -z "$DJANGO_SUPERUSER_EMAIL" ] || [ -z "$DJANGO_SUPERUSER_PASSWORD" ]; then
  echo "Superuser data is not provided/fully provided. Please re-check the .env file or runtime env variable"
  exit 1
fi

# If all data is provided, auto-create/update superuser through Django shell
echo "Checking superuser..."
python manage.py shell <<'EOF'
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password
import os

User = get_user_model()
username = os.getenv("DJANGO_SUPERUSER_USERNAME")
email = os.getenv("DJANGO_SUPERUSER_EMAIL")
password = os.getenv("DJANGO_SUPERUSER_PASSWORD")

try:
    user = User.objects.get(username=username)
    print(f"[i] Superuser '{username}' already exists.")
    # Only update if password is different
    if not check_password(password, user.password):
        user.set_password(password)
        user.save()
        print(f"[+] Password for '{username}' updated.")
    else:
        print(f"[i] Password for '{username}' is already up-to-date.")
except User.DoesNotExist:
    user = User.objects.create_superuser(username=username, email=email or '', password=password)
    print(f"[+] Superuser '{username}' created successfully.")
EOF

# Start server based on .env value or overridden at runtime
if [ "$ENVIRONMENT" = "production" ]; then
  echo "Starting Gunicorn for production..."
  gunicorn truck_signs_designs.wsgi:application --bind 0.0.0.0:8000
else
  echo "Starting Django development server"
  python manage.py runserver 0.0.0.0:8000
fi