"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const mockSeries = Array.from({ length: 14 }).map((_, i) => ({
  t: `T-${13 - i}`,
  req: 40 + Math.round(Math.sin(i / 2) * 25 + Math.random() * 15),
  err: Math.round(Math.random() * 3),
}));

export default function MetricsPage() {
  return (
    <div>
      <PageHeader
        title="Métricas"
        description="Serie ilustrativa de throughput y errores (cliente). Conecta CloudWatch para datos reales."
      />
      <Card className="border-border/80">
        <CardHeader>
          <CardTitle className="text-base">Solicitudes simuladas</CardTitle>
        </CardHeader>
        <CardContent className="h-[320px] w-full pl-0">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={mockSeries} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id="fillReq" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="hsl(221, 83%, 53%)" stopOpacity={0.35} />
                  <stop offset="95%" stopColor="hsl(221, 83%, 53%)" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" className="stroke-border/80" />
              <XAxis dataKey="t" tick={{ fontSize: 11 }} stroke="hsl(var(--muted-foreground))" />
              <YAxis tick={{ fontSize: 11 }} stroke="hsl(var(--muted-foreground))" />
              <Tooltip
                contentStyle={{
                  borderRadius: 8,
                  border: "1px solid hsl(var(--border))",
                  background: "hsl(var(--card))",
                }}
              />
              <Area
                type="monotone"
                dataKey="req"
                name="req/s"
                stroke="hsl(221, 83%, 53%)"
                fill="url(#fillReq)"
                strokeWidth={2}
              />
            </AreaChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>
    </div>
  );
}
