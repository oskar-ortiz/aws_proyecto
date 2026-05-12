"use client";

import * as React from "react";
import { Activity, Cloud, Database, Mail, Server, Zap } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { fetchDashboardContext } from "@/lib/api";
import type { DashboardContext } from "@/lib/types";

export default function OverviewPage() {
  const [ctx, setCtx] = React.useState<DashboardContext | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [adminOk, setAdminOk] = React.useState<boolean | null>(null);
  const [host, setHost] = React.useState("");

  React.useEffect(() => {
    setHost(typeof window !== "undefined" ? window.location.host : "");
  }, []);

  React.useEffect(() => {
    let cancelled = false;
    (async () => {
      const [c, h] = await Promise.all([
        fetchDashboardContext(),
        fetch("/admin/health", { cache: "no-store", credentials: "same-origin" }),
      ]);
      if (!cancelled) {
        setCtx(c);
        setAdminOk(h.ok);
        setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const accountId =
    process.env.NEXT_PUBLIC_AWS_ACCOUNT_ID?.trim() || "— (opcional NEXT_PUBLIC_AWS_ACCOUNT_ID)";

  return (
    <div>
      <PageHeader
        title="Overview"
        description="Resumen del entorno desplegado. Datos de backend vía rutas relativas /admin; Lambda vía /api."
      />
      {loading ? (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-32 rounded-xl" />
          ))}
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <StatCard
            icon={<Activity className="h-4 w-4" />}
            title="Estado general"
            value="Healthy"
            badge={<Badge variant="success">OK</Badge>}
            hint="ALB → EC2 responde"
          />
          <StatCard
            icon={<Cloud className="h-4 w-4" />}
            title="Región"
            value={ctx?.region ?? "—"}
            hint="Desde /admin/dashboard-context"
          />
          <StatCard
            icon={<Server className="h-4 w-4" />}
            title="Account ID"
            value={accountId}
            hint="Build-time opcional"
          />
          <StatCard
            icon={<Cloud className="h-4 w-4" />}
            title="DNS del ALB"
            value={host || "—"}
            hint="Mismo host que sirve este dashboard"
          />
          <StatCard
            icon={<Server className="h-4 w-4" />}
            title="Instancias ASG"
            value={
              ctx
                ? `${ctx.asg_desired} deseadas · min ${ctx.asg_min} / max ${ctx.asg_max}`
                : "—"
            }
            hint="Valores desde backend (env ASG_*)"
          />
          <StatCard
            icon={<Database className="h-4 w-4" />}
            title="DB primary"
            value={truncateHost(ctx?.db_write_host)}
            hint="Writer endpoint"
          />
          <StatCard
            icon={<Database className="h-4 w-4" />}
            title="DB replica"
            value={truncateHost(ctx?.db_read_host)}
            hint="Reader endpoint"
          />
          <StatCard
            icon={<Zap className="h-4 w-4" />}
            title="Backend /admin"
            value={adminOk === true ? "Respondiendo" : adminOk === false ? "Error" : "—"}
            badge={
              adminOk === true ? (
                <Badge variant="success">OK</Badge>
              ) : adminOk === false ? (
                <Badge variant="warning">Revisar</Badge>
              ) : null
            }
          />
          <StatCard
            icon={<Zap className="h-4 w-4" />}
            title="Lambda /api"
            value="Regla ALB activa"
            badge={<Badge variant="secondary">Integrado</Badge>}
            hint="Sin ping automático (evita efectos secundarios SES)"
          />
          <StatCard
            icon={<Mail className="h-4 w-4" />}
            title="SES"
            value={ctx?.ses_sender ? "Remitente configurado" : "—"}
            badge={<Badge variant="outline">Sandbox</Badge>}
            hint={ctx?.ses_sender ?? ""}
          />
        </div>
      )}
    </div>
  );
}

function truncateHost(h?: string) {
  if (!h) return "—";
  return h.length > 42 ? `${h.slice(0, 40)}…` : h;
}

function StatCard({
  icon,
  title,
  value,
  hint,
  badge,
}: {
  icon: React.ReactNode;
  title: string;
  value: string;
  hint?: string;
  badge?: React.ReactNode;
}) {
  return (
    <Card className="overflow-hidden border-border/80 shadow-sm transition-shadow hover:shadow-md">
      <CardHeader className="flex flex-row items-start justify-between space-y-0 pb-2">
        <div className="flex items-center gap-2 text-muted-foreground">
          {icon}
          <CardTitle className="text-sm font-medium">{title}</CardTitle>
        </div>
        {badge}
      </CardHeader>
      <CardContent>
        <p className="break-all font-mono text-sm font-semibold leading-snug text-foreground">
          {value}
        </p>
        {hint ? (
          <p className="mt-2 text-xs text-muted-foreground line-clamp-2">{hint}</p>
        ) : null}
      </CardContent>
    </Card>
  );
}
