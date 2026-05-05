# Sistema de Matricula Universitaria en AWS

Proyecto base para desplegar una plataforma de matricula universitaria altamente disponible con:

- EC2 con NGINX + backend Flask
- ALB con path-based routing
- Lambda integrada directamente con ALB
- RDS MySQL Multi-AZ + Read Replica
- SES para correos de confirmacion
- Auto Scaling Group con Step Scaling

## Estructura

```text
.
|-- app/
|   `-- backend/
|-- lambda/
|-- modules/
|   |-- alb/
|   |-- compute/
|   |-- database/
|   |-- network/
|   `-- security/
|-- nginx/
|-- scripts/
|-- main.tf
|-- variables.tf
`-- outputs.tf
```

## Diagrama ASCII

```text
                        Internet
                            |
                            v
                  +----------------------+
                  |   Application LB     |
                  |  path-based routing  |
                  +----------------------+
                   |                  |
        /admin/* ->|                  |-> /api/*
                   v                  v
      +--------------------+   +-------------------+
      | Target Group EC2   |   | Target Group      |
      | Auto Scaling Group |   | Lambda            |
      +--------------------+   +-------------------+
               |                          |
               v                          v
      +--------------------+     +------------------+
      | EC2 private subnets|     | Lambda in VPC    |
      | NGINX + Flask app  |     | SES email sender |
      +--------------------+     +------------------+
               |                          |
               +------------+-------------+
                            |
                            v
              +-----------------------------+
              | RDS MySQL Multi-AZ Primary |
              +-----------------------------+
                            |
                            v
              +-----------------------------+
              | Read Replica for queries   |
              +-----------------------------+
```

## Flujo funcional

1. Cliente o panel admin llama `POST /admin/enrollments`.
2. La app en EC2 escribe la matricula en el endpoint writer de RDS.
3. Consultas `GET /admin/enrollments` leen desde la Read Replica.
4. Cliente o proceso externo llama `POST /api/confirm`.
5. El ALB invoca Lambda directamente.
6. Lambda envia correo con SES; si falla, reintenta con backoff exponencial hasta 3 veces.
7. Si los 3 intentos fallan, Lambda guarda el error en la tabla `email_failures`.

## Despliegue CLI con PowerShell

1. Empaqueta la Lambda:

```powershell
.\scripts\package_lambda.ps1
```

2. Ejecuta el despliegue completo:

```powershell
.\scripts\aws_cli_deploy.ps1 `
  -SesSenderEmail "remitente-verificado@dominio.com" `
  -SesRecipientEmail "destinatario-verificado@dominio.com" `
  -DbPassword "ChangeMe123!"
```

3. Verifica el flujo de aplicación:

```powershell
.\scripts\aws_cli_verify.ps1 -StudentEmail "destinatario-verificado@dominio.com"
```

4. Ejecuta failover controlado:

```powershell
.\scripts\aws_cli_failover_test.ps1
```

## Terraform alternativo

Si prefieres IaC con Terraform, la base también está incluida en este repositorio.

## Endpoints

- `GET /health`
- `GET /admin/health`
- `POST /admin/enrollments`
- `GET /admin/enrollments`
- `POST /api/confirm`

Ejemplo de matricula:

```bash
curl -X POST "http://ALB_DNS/admin/enrollments" \
  -H "Content-Type: application/json" \
  -d '{"student_name":"Ana Perez","student_email":"verified-recipient@example.com","course_code":"CS101"}'
```

Ejemplo de correo:

```bash
curl -X POST "http://ALB_DNS/api/confirm" \
  -H "Content-Type: application/json" \
  -d '{"enrollment_id":1,"student_name":"Ana Perez","student_email":"verified-recipient@example.com","course_code":"CS101"}'
```

## Pruebas de carga

Desde una EC2 de pruebas:

```bash
chmod +x scripts/load_test.sh
./scripts/load_test.sh ALB_DNS
```

## Explicacion breve

### Failover en RDS Multi-AZ

RDS mantiene una instancia standby sincronizada en otra AZ. Si la primaria falla por problema de infraestructura, almacenamiento o AZ, AWS promueve automaticamente la standby y actualiza el endpoint writer para que la aplicacion siga usando el mismo hostname principal.

### Como funciona ALB con Lambda

El ALB no abre una conexion TCP hacia Lambda. En lugar de eso, cuando una regla del listener coincide con `/api/*`, el ALB transforma la solicitud HTTP en un evento JSON e invoca la funcion Lambda registrada en el target group de tipo `lambda`. La respuesta de Lambda se devuelve como respuesta HTTP del ALB.

## Notas operativas

- En sandbox de SES, tanto remitente como destinatario deben estar verificados.
- El proyecto usa una sola NAT Gateway para simplificar y abaratar; para HA completa de salida, usa una NAT por AZ.
- La password de RDS se pasa como variable sensible. En produccion, mueve esto a Secrets Manager o SSM Parameter Store.
- El despliegue CLI guarda evidencia operativa en `scripts/deployment-output.json`.
