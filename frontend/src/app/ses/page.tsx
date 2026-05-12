"use client";

import * as React from "react";
import { toast } from "sonner";
import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { fetchDashboardContext, postSesTest } from "@/lib/api";
import type { DashboardContext } from "@/lib/types";

const mockLog = [
  { t: "10:02:01", m: "Queued · confirmación matrícula #104" },
  { t: "10:01:44", m: "250 OK · sandbox SES" },
  { t: "09:58:12", m: "MessageId simulado · cw-mock" },
];

export default function SesPage() {
  const [ctx, setCtx] = React.useState<DashboardContext | null>(null);
  const [email, setEmail] = React.useState("");
  const [name, setName] = React.useState("Prueba Dashboard");
  const [course, setCourse] = React.useState("CS101");
  const [busy, setBusy] = React.useState(false);

  React.useEffect(() => {
    fetchDashboardContext().then(setCtx);
  }, []);

  async function sendTest() {
    setBusy(true);
    try {
      const res = await postSesTest({
        student_email: email.trim(),
        student_name: name.trim(),
        course_code: course.trim(),
        enrollment_id: 0,
      });
      if (res.ok) {
        toast.success("Solicitud enviada a /api/confirm", {
          description: JSON.stringify(res.json),
        });
      } else {
        toast.error(`HTTP ${res.status}`, {
          description: JSON.stringify(res.json),
        });
      }
    } catch (e) {
      toast.error("Error de red", { description: String(e) });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="SES / Email"
        description="Remitente desde el backend. La prueba invoca la Lambda real por POST /api/confirm (mismo origen)."
      />
      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-border/80">
          <CardHeader>
            <CardTitle className="text-base">Configuración</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div>
              <p className="text-xs text-muted-foreground">Remitente verificado</p>
              <p className="font-mono text-sm">{ctx?.ses_sender || "—"}</p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Destinatario (formulario)</p>
              <p className="text-sm text-muted-foreground">
                Debe estar verificado en SES sandbox para entrega exitosa.
              </p>
            </div>
            <div className="flex flex-wrap gap-2 pt-2">
              <Badge variant="outline">Sandbox</Badge>
              <Badge variant="secondary">Same-origin /api</Badge>
            </div>
          </CardContent>
        </Card>
        <Card className="border-border/80">
          <CardHeader>
            <CardTitle className="text-base">Enviar prueba</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="em">student_email</Label>
              <Input
                id="em"
                type="email"
                placeholder="correo verificado en SES"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="nm">student_name</Label>
              <Input
                id="nm"
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="cc">course_code</Label>
              <Input
                id="cc"
                value={course}
                onChange={(e) => setCourse(e.target.value)}
              />
            </div>
            <Button className="w-full" disabled={busy || !email.trim()} onClick={sendTest}>
              {busy ? "Enviando…" : "Enviar prueba → /api/confirm"}
            </Button>
          </CardContent>
        </Card>
      </div>
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Historial envíos (mock visual)</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-2 font-mono text-xs">
            {mockLog.map((row) => (
              <li
                key={row.t}
                className="flex gap-3 rounded-lg border border-border/60 bg-muted/30 px-3 py-2"
              >
                <span className="text-muted-foreground">{row.t}</span>
                <span>{row.m}</span>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>
    </div>
  );
}
