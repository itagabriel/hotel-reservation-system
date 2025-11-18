#!/bin/sh
set -e

echo "🚀 Initializing application entrypoint..."

# -------------------------------------------------------------------------
# Aguarda a disponibilidade do banco de dados PostgreSQL
# -------------------------------------------------------------------------
echo "⏳ Waiting for PostgreSQL availability..."
while ! nc -z db 5432; do
  echo "🟡 PostgreSQL is not ready yet. Retrying..."
  sleep 2
done
echo "✅ PostgreSQL connection established!"

# -------------------------------------------------------------------------
# Executa migrações do Django
# -------------------------------------------------------------------------
echo "⚙️ Applying Django migrations..."
python manage.py migrate --noinput

# -------------------------------------------------------------------------
# Coleta arquivos estáticos (somente se for o web)
# -------------------------------------------------------------------------
if [ "$RUN_GUNICORN" = "1" ]; then
    echo "📦 Collecting static files..."
    python manage.py collectstatic --noinput
fi

# -------------------------------------------------------------------------
# Cria superusuário automaticamente
# -------------------------------------------------------------------------
echo "👤 Verifying admin user existence..."
python << END
import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", os.getenv("DJANGO_SETTINGS_MODULE", "core.settings"))
django.setup()

from django.contrib.auth import get_user_model
User = get_user_model()

username = os.getenv("DJANGO_SUPERUSER_USERNAME", "admin")
email = os.getenv("DJANGO_SUPERUSER_EMAIL", "admin@example.com")
password = os.getenv("DJANGO_SUPERUSER_PASSWORD", "admin123")

user, created = User.objects.get_or_create(username=username, defaults={'email': email})
if created:
    user.set_password(password)
    user.is_superuser = True
    user.is_staff = True
    user.save()
    print("🟢 Superuser created successfully!")
else:
    print("ℹ️ Superuser already exists. Skipping creation.")
END

# -------------------------------------------------------------------------
# Executa o comando passado para o container
# -------------------------------------------------------------------------
if [ "$RUN_GUNICORN" = "1" ]; then
    echo "🚀 Starting Gunicorn application server..."
    exec gunicorn core.wsgi:application --bind 0.0.0.0:8000
else
    echo "🚀 Running custom command..."
    exec "$@"
fi
