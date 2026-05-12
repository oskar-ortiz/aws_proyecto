import { FileImage, FileText, Link2 } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const items = [
  {
    title: "Despliegue CLI",
    desc: "Salida de aws_cli_deploy.ps1 y recursos creados (ALB, ASG, RDS, Lambda).",
    icon: FileText,
  },
  {
    title: "Capturas de arquitectura",
    desc: "Diagramas de consola AWS y diagramas de red en la carpeta de documentación del proyecto.",
    icon: FileImage,
  },
  {
    title: "Enlaces útiles",
    desc: "ALB DNS, consola RDS, grupos de Auto Scaling y función Lambda desde la consola AWS.",
    icon: Link2,
  },
];

export default function EvidencePage() {
  return (
    <div>
      <PageHeader
        title="Evidencias"
        description="Checklist de artefactos habituales para auditoría académica o revisión de arquitectura."
      />
      <div className="grid gap-4 md:grid-cols-3">
        {items.map((it) => {
          const Icon = it.icon;
          return (
            <Card
              key={it.title}
              className="border-border/80 transition-all hover:border-primary/25 hover:shadow-md"
            >
              <CardHeader>
                <Icon className="mb-2 h-8 w-8 text-primary" />
                <CardTitle className="text-base">{it.title}</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">{it.desc}</p>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
