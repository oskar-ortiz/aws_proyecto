"use client";

import * as React from "react";
import { PageHeader } from "@/components/page-header";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { fetchDashboardContext } from "@/lib/api";
import type { DashboardContext } from "@/lib/types";

export default function RdsPage() {
  const [ctx, setCtx] = React.useState<DashboardContext | null>(null);
  const [lagMs, setLagMs] = React.useState<number | null>(null);

  React.useEffect(() => {
    fetchDashboardContext().then((c) => {
      setCtx(c);
      setLagMs(80 + Math.round(Math.random() * 120));
    });
  }, []);

  return (
    <div className="space-y-6">
      <PageHeader
        title="RDS Health"
        description="Endpoints expuestos de forma segura solo al backend; aquí se muestran lecturas no sensibles."
      />
      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-border/80">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-base">Writer (primary)</CardTitle>
            <Badge variant="success">Multi-AZ</Badge>
          </CardHeader>
          <CardContent>
            <p className="break-all font-mono text-sm">{ctx?.db_write_host || "—"}</p>
          </CardContent>
        </Card>
        <Card className="border-border/80">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-base">Reader (replica)</CardTitle>
            <Badge variant="secondary">Read</Badge>
          </CardHeader>
          <CardContent>
            <p className="break-all font-mono text-sm">{ctx?.db_read_host || "—"}</p>
          </CardContent>
        </Card>
      </div>
      <div className="grid gap-4 sm:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">Base de datos</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-lg font-semibold">{ctx?.db_name || "—"}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">Réplica lag (sim)</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-lg font-semibold tabular-nums">
              {lagMs != null ? `${lagMs} ms` : "—"}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">Salud</CardTitle>
          </CardHeader>
          <CardContent>
            <Badge variant="success" className="text-sm">
              Operativo
            </Badge>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
