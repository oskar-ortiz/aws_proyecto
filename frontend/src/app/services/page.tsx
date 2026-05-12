import {
  Boxes,
  Database,
  Globe,
  Mail,
  Network,
  Shield,
  Zap,
} from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const services = [
  {
    name: "VPC & subnets",
    desc: "Red pública para ALB, privada para EC2, Lambda y RDS.",
    icon: Network,
  },
  {
    name: "Application Load Balancer",
    desc: "Enrutamiento por path a ASG y función Lambda.",
    icon: Globe,
  },
  {
    name: "EC2 Auto Scaling",
    desc: "NGINX reverse proxy y API Flask bajo /admin.",
    icon: Boxes,
  },
  {
    name: "Lambda",
    desc: "Confirmaciones y correo vía SES en /api/*.",
    icon: Zap,
  },
  {
    name: "RDS MySQL",
    desc: "Multi-AZ writer y read replica para consultas.",
    icon: Database,
  },
  {
    name: "SES",
    desc: "Correo transaccional en modo sandbox verificado.",
    icon: Mail,
  },
  {
    name: "Seguridad",
    desc: "Security groups, IAM mínimo necesario, sin secretos en el cliente.",
    icon: Shield,
  },
];

export default function ServicesPage() {
  return (
    <div>
      <PageHeader
        title="Servicios AWS"
        description="Componentes típicos del stack desplegado para matrículas y notificaciones."
      />
      <div className="grid gap-4 sm:grid-cols-2">
        {services.map((s) => (
          <Card
            key={s.name}
            className="group border-border/80 transition-all hover:border-primary/30 hover:shadow-md"
          >
            <CardHeader className="flex flex-row items-center gap-3 space-y-0">
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 text-primary transition-colors group-hover:bg-primary/15">
                <s.icon className="h-5 w-5" />
              </div>
              <CardTitle className="text-base">{s.name}</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">{s.desc}</p>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
