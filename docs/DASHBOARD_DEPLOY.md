# Dashboard Next.js (`/dashboard`)

Frontend estático (App Router + `output: 'export'`) servido por NGINX en las instancias EC2. No modifica `aws_cli_deploy.ps1`: el script sigue leyendo `nginx/nginx.conf` desde disco al generar user-data.

## Requisitos previos

1. **ALB**: el tráfico `/dashboard` y `/dashboard/*` debe ir al target group de EC2 (mismo que `/admin/*`).
   - **Terraform**: la regla `aws_lb_listener_rule.dashboard` ya está en `modules/alb/main.tf`.
   - **Solo CLI (stack ya desplegado)**: ejecuta una vez:

     ```powershell
     .\scripts\aws_cli_add_dashboard_alb_rule.ps1 -AwsRegion "us-east-1" -ProjectName "university-enrollment"
     ```

2. **NGINX + directorio**: `nginx/nginx.conf` sirve los archivos bajo `root /opt/university/frontend/out;` y `location /dashboard/`. Las instancias deben tener el directorio creado (Terraform user-data crea `/opt/university/frontend/out`; en despliegues antiguos, créalo con `sudo mkdir -p /opt/university/frontend/out`).

## Despliegue automático a EC2 (recomendado)

Desde `C:\aws_proyecto` (requiere SSM en las instancias y bucket S3 en la cuenta; la primera vez crea el bucket):

```powershell
Set-Location C:\aws_proyecto
.\scripts\deploy_dashboard_to_ec2.ps1 -AwsRegion us-east-1 -CreateBucketIfMissing
```

Usa `scripts\deployment-output.json` para ASG e instancias. Opcional: `-AsgName "university-enrollment-....-asg"` o `-SkipBuild`.

## Build local

```powershell
.\scripts\build-dashboard.ps1
```

O manualmente:

```powershell
cd frontend
npm ci
npm run build
```

Salida: `frontend/out/` con `index.html` en la raíz del export, carpetas por ruta (`autoscaling/index.html`, etc.) y `_next/` en la raíz. Las URLs públicas siguen siendo `/dashboard/...` (basePath); NGINX reescribe internamente a esos ficheros.

## Copiar a EC2

Sustituye `USER`, `HOST` (bastion o IP privada vía SSM) y la ruta de clave.

```powershell
scp -i key.pem -r frontend/out/* USER@HOST:/tmp/dashboard-out/
```

En la instancia:

```bash
sudo rm -rf /opt/university/frontend/out/*
sudo cp -a /tmp/dashboard-out/. /opt/university/frontend/out/
sudo nginx -t && sudo systemctl reload nginx
```

Si actualizas **solo** NGINX desde el repo (sin reconstruir AMIs), copia el nuevo `nginx/nginx.conf` a `/etc/nginx/nginx.conf`, valida y recarga.

## Variables opcionales (Overview)

- `NEXT_PUBLIC_AWS_ACCOUNT_ID`: se inyecta en build (no es secreto en UI). Ejemplo:

  ```powershell
  $env:NEXT_PUBLIC_AWS_ACCOUNT_ID = "123456789012"
  .\scripts\build-dashboard.ps1
  ```

## Backend: contexto ASG

`GET /admin/dashboard-context` lee `ASG_MIN_SIZE`, `ASG_MAX_SIZE`, `ASG_DESIRED_CAPACITY` del `.env` en la instancia (opcional). Si no existen, usa los mismos valores por defecto que el script de despliegue (2 / 6 / 2). Puedes añadir al `/opt/university/app/.env`:

```env
ASG_MIN_SIZE=2
ASG_MAX_SIZE=6
ASG_DESIRED_CAPACITY=2
```

Reinicia el servicio Flask si cambias el `.env`.

## Integración segura (resumen)

- El navegador usa **el mismo origen** que el ALB: rutas relativas `/admin/*` y `/api/*` evitan hardcodear dominios y cookies/same-origin siguen alineados con el balanceador.
- **No** se exponen credenciales RDS ni claves en el frontend; solo datos ya previstos para operadores (endpoints de base, región, remitente SES).
- `/api/confirm` sigue siendo la Lambda detrás del ALB; el dashboard solo hace `POST` JSON como cualquier otro cliente autorizado en tu red.

## Cero impacto en el CLI principal

- `scripts/aws_cli_deploy.ps1` **no** se edita.
- Los cambios de ALB para `/dashboard` son **aditivos** (nueva regla o Terraform apply).
- `/admin/*`, `/api/*`, RDS, Lambda e IAM existentes permanecen igual; NGINX solo añade `location` para el estático.
