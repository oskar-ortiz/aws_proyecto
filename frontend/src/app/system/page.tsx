"use client";

import * as React from "react";
import { PageHeader } from "@/components/page-header";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default function SystemPage() {
  const [health, setHealth] = React.useState<{
    admin?: unknown;
    root?: unknown;
  }>({});
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    let cancelled = false;
    (async () => {
      const [a, r] = await Promise.all([
        fetch("/admin/health", { credentials: "same-origin" }).then((x) =>
          x.json().catch(() => null),
        ),
        fetch("/health", { credentials: "same-origin" }).then((x) =>
          x.json().catch(() => null),
        ),
      ]);
      if (!cancelled) {
        setHealth({ admin: a, root: r });
        setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div>
      <PageHeader
        title="Estado del sistema"
        description="Health checks expuestos detrás del mismo ALB (rutas relativas)."
      />
      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-border/80">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-base">/health (ALB → EC2)</CardTitle>
            {!loading ? (
              <Badge variant={health.root ? "success" : "warning"}>
                {health.root ? "JSON" : "Sin datos"}
              </Badge>
            ) : null}
          </CardHeader>
          <CardContent>
            <pre className="max-h-64 overflow-auto rounded-lg bg-muted/50 p-4 text-xs leading-relaxed">
              {loading ? "Cargando…" : JSON.stringify(health.root, null, 2)}
            </pre>
          </CardContent>
        </Card>
        <Card className="border-border/80">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-base">/admin/health</CardTitle>
            {!loading ? (
              <Badge variant={health.admin ? "success" : "warning"}>
                {health.admin ? "JSON" : "Sin datos"}
              </Badge>
            ) : null}
          </CardHeader>
          <CardContent>
            <pre className="max-h-64 overflow-auto rounded-lg bg-muted/50 p-4 text-xs leading-relaxed">
              {loading ? "Cargando…" : JSON.stringify(health.admin, null, 2)}
            </pre>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
