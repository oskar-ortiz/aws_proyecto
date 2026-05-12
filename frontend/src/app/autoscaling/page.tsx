"use client";

import * as React from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { fetchDashboardContext } from "@/lib/api";
import type { DashboardContext } from "@/lib/types";

const scaleEvents = [
  { day: "Lun", desired: 2, cpu: 38 },
  { day: "Mar", desired: 2, cpu: 52 },
  { day: "Mié", desired: 3, cpu: 71 },
  { day: "Jue", desired: 4, cpu: 78 },
  { day: "Vie", desired: 3, cpu: 55 },
  { day: "Sáb", desired: 2, cpu: 41 },
  { day: "Dom", desired: 2, cpu: 33 },
];

export default function AutoscalingPage() {
  const [ctx, setCtx] = React.useState<DashboardContext | null>(null);

  React.useEffect(() => {
    fetchDashboardContext().then(setCtx);
  }, []);

  return (
    <div className="space-y-6">
      <PageHeader
        title="EC2 / Auto Scaling"
        description="Límites desde el backend y tendencias ilustrativas. Alarmas CPU típicas en CloudWatch."
      />
      <div className="grid gap-4 lg:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Mínimo
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-semibold tabular-nums">{ctx?.asg_min ?? "—"}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Máximo
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-semibold tabular-nums">{ctx?.asg_max ?? "—"}</p>
          </CardContent>
        </Card>
        <Card className="border-primary/20">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Deseadas (env)
            </CardTitle>
          </CardHeader>
          <CardContent className="flex items-center justify-between">
            <p className="text-3xl font-semibold tabular-nums">
              {ctx?.asg_desired ?? "—"}
            </p>
            <Badge variant="success">Estable</Badge>
          </CardContent>
        </Card>
      </div>
      <Card className="border-border/80">
        <CardHeader>
          <CardTitle className="text-base">CPU estimada vs capacidad deseada</CardTitle>
        </CardHeader>
        <CardContent className="h-[300px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={scaleEvents}>
              <CartesianGrid strokeDasharray="3 3" className="stroke-border/80" />
              <XAxis dataKey="day" tick={{ fontSize: 11 }} />
              <YAxis yAxisId="left" tick={{ fontSize: 11 }} />
              <YAxis yAxisId="right" orientation="right" tick={{ fontSize: 11 }} />
              <Tooltip
                contentStyle={{
                  borderRadius: 8,
                  border: "1px solid hsl(var(--border))",
                  background: "hsl(var(--card))",
                }}
              />
              <Legend />
              <Line
                yAxisId="left"
                type="monotone"
                dataKey="cpu"
                name="CPU %"
                stroke="hsl(38, 92%, 50%)"
                strokeWidth={2}
                dot={{ r: 3 }}
              />
              <Line
                yAxisId="right"
                type="stepAfter"
                dataKey="desired"
                name="Instancias"
                stroke="hsl(221, 83%, 53%)"
                strokeWidth={2}
              />
            </LineChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>
      <Card className="border-border/80">
        <CardHeader>
          <CardTitle className="text-base">Historial de scale-out (mock)</CardTitle>
        </CardHeader>
        <CardContent className="h-[240px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={scaleEvents}>
              <CartesianGrid strokeDasharray="3 3" className="stroke-border/80" />
              <XAxis dataKey="day" tick={{ fontSize: 11 }} />
              <YAxis tick={{ fontSize: 11 }} />
              <Tooltip
                contentStyle={{
                  borderRadius: 8,
                  border: "1px solid hsl(var(--border))",
                  background: "hsl(var(--card))",
                }}
              />
              <Bar dataKey="desired" name="Desired" fill="hsl(221, 83%, 53%)" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>
    </div>
  );
}
