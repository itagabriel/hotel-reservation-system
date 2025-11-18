#!/bin/sh

set -e

echo "🚀 Initializing application entrypoint..."

# -------------------------------------------------------------------------
# Aguarda a disponibilidade do banco de dados PostgreSQL antes de iniciar
# -------------------------------------------------------------------------
echo "⏳ Waiting for PostgreSQL availability..."
while ! nc -z db 5432; do
  echo "🟡 PostgreSQL is not ready yet. Retrying..."
  sleep 2
done
echo "✅ PostgreSQL connection established!"

# -------------------------------------------------------------------------
# Executa migrações do Django garantindo que a base esteja sempre atualizada
# -------------------------------------------------------------------------
echo "⚙️ Applying Django migrations..."
python manage.py migrate --noinput

# -------------------------------------------------------------------------
# Coleta arquivos estáticos usados em produção (CSS, JS, imagens, etc.)
# -------------------------------------------------------------------------
echo "📦 Collecting static files..."
python manage.py collectstatic --noinput

# -------------------------------------------------------------------------
# Cria um superusuário automaticamente caso ele ainda não exista
# -------------------------------------------------------------------------
echo "👤 Verifying admin user existence..."
python << END
from django.contrib.auth import get_user_model
User = get_user_model()
import os

username = os.getenv("DJANGO_SUPERUSER_USERNAME", "admin")
email = os.getenv("DJANGO_SUPERUSER_EMAIL", "admin@example.com")
password = os.getenv("DJANGO_SUPERUSER_PASSWORD", "admin123")

if not User.objects.filter(username=username).exists():
    User.objects.create_superuser(username=username, email=email, password=password)
    print("🟢 Superuser created successfully!")
else:
    print("ℹ️ Superuser already exists. Skipping creation.")
END

# -------------------------------------------------------------------------
# Inicializa o servidor WSGI usando Gunicorn (ideal para produção)
# -------------------------------------------------------------------------
echo "🚀 Starting Gunicorn application server..."
exec gunicorn core.wsgi:application --bind 0.0.0.0:8000
