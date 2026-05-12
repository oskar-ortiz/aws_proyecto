"use client";

import * as React from "react";
import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";

type RunResult = {
  ok: number;
  fail: number;
  ms: number;
  total: number;
};

export default function TestsPage() {
  const [users, setUsers] = React.useState(25);
  const [requests, setRequests] = React.useState(100);
  const [running, setRunning] = React.useState(false);
  const [last, setLast] = React.useState<RunResult | null>(null);

  async function runBench() {
    setRunning(true);
    const started = performance.now();
    const total = Math.max(1, users) * Math.max(1, requests);
    const chunk = Array.from({ length: Math.min(total, 500) }, () =>
      fetch("/admin/health", { method: "GET", credentials: "same-origin" }).then(
        (r) => r.ok,
        () => false,
      ),
    );
    const results = await Promise.all(chunk);
    const ok = results.filter(Boolean).length;
    const ms = Math.round(performance.now() - started);
    setLast({ ok, fail: results.length - ok, ms, total: results.length });
    setRunning(false);
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Load tests"
        description="Disparo concurrente real contra /admin/health (capado a 500 solicitudes por ejecución para proteger el entorno)."
      />
      <Card className="max-w-xl border-border/80">
        <CardHeader>
          <CardTitle className="text-base">Parámetros</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label>Usuarios concurrentes (meta)</Label>
              <Input
                type="number"
                min={1}
                value={users}
                onChange={(e) => setUsers(Number(e.target.value))}
              />
            </div>
            <div className="space-y-2">
              <Label>Requests por usuario (meta)</Label>
              <Input
                type="number"
                min={1}
                value={requests}
                onChange={(e) => setRequests(Number(e.target.value))}
              />
            </div>
          </div>
          <Button onClick={runBench} disabled={running}>
            {running ? "Ejecutando…" : "Ejecutar benchmark"}
          </Button>
        </CardContent>
      </Card>
      {last ? (
        <div className="grid gap-4 sm:grid-cols-4">
          <ResultTile label="OK" value={String(last.ok)} variant="success" />
          <ResultTile label="Fallos" value={String(last.fail)} variant="warning" />
          <ResultTile label="Tiempo" value={`${last.ms} ms`} />
          <ResultTile label="Ejecutadas" value={String(last.total)} />
        </div>
      ) : null}
    </div>
  );
}

function ResultTile({
  label,
  value,
  variant,
}: {
  label: string;
  value: string;
  variant?: "success" | "warning";
}) {
  return (
    <Card className="border-border/80">
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center justify-between text-sm font-medium text-muted-foreground">
          {label}
          {variant ? <Badge variant={variant}>{variant === "success" ? "OK" : "!"}</Badge> : null}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums">{value}</p>
      </CardContent>
    </Card>
  );
}
