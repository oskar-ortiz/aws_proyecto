"use client";

import * as React from "react";
import { Plus } from "lucide-react";
import { toast } from "sonner";
import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Skeleton } from "@/components/ui/skeleton";
import { createEnrollment, fetchEnrollments } from "@/lib/api";
import type { EnrollmentRow } from "@/lib/types";

export default function EnrollmentsPage() {
  const [rows, setRows] = React.useState<EnrollmentRow[]>([]);
  const [source, setSource] = React.useState("");
  const [loading, setLoading] = React.useState(true);
  const [open, setOpen] = React.useState(false);
  const [form, setForm] = React.useState({
    student_name: "",
    student_email: "",
    course_code: "",
  });
  const [saving, setSaving] = React.useState(false);

  async function load() {
    setLoading(true);
    const data = await fetchEnrollments();
    if (data) {
      setRows(data.items);
      setSource(data.source);
    } else {
      setRows([]);
      setSource("");
    }
    setLoading(false);
  }

  React.useEffect(() => {
    load();
  }, []);

  async function onCreate() {
    setSaving(true);
    const res = await createEnrollment(form);
    setSaving(false);
    if (res.ok) {
      toast.success("Matrícula creada", {
        description: typeof res.json === "object" ? JSON.stringify(res.json) : "",
      });
      setOpen(false);
      setForm({ student_name: "", student_email: "", course_code: "" });
      await load();
    } else {
      toast.error(`Error ${res.status}`, {
        description: JSON.stringify(res.json),
      });
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <PageHeader
          title="Matrículas"
          description="GET/POST reales contra /admin/enrollments (réplica para lectura)."
          className="mb-0 sm:mb-0"
        />
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button className="shrink-0 gap-2 self-start sm:self-auto">
              <Plus className="h-4 w-4" />
              Nueva matrícula
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Nueva matrícula</DialogTitle>
              <DialogDescription>
                POST al backend Flask. Tras crear, puedes usar /api/confirm para el correo.
              </DialogDescription>
            </DialogHeader>
            <div className="grid gap-3 py-2">
              <div className="space-y-2">
                <Label htmlFor="sn">student_name</Label>
                <Input
                  id="sn"
                  value={form.student_name}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, student_name: e.target.value }))
                  }
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="se">student_email</Label>
                <Input
                  id="se"
                  type="email"
                  value={form.student_email}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, student_email: e.target.value }))
                  }
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="cc">course_code</Label>
                <Input
                  id="cc"
                  value={form.course_code}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, course_code: e.target.value }))
                  }
                />
              </div>
            </div>
            <DialogFooter>
              <Button variant="secondary" onClick={() => setOpen(false)}>
                Cancelar
              </Button>
              <Button
                disabled={
                  saving ||
                  !form.student_name.trim() ||
                  !form.student_email.trim() ||
                  !form.course_code.trim()
                }
                onClick={onCreate}
              >
                {saving ? "Guardando…" : "Crear"}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
      <div className="flex items-center gap-2">
        <Badge variant="outline">Fuente: {source || "—"}</Badge>
        <Button variant="ghost" size="sm" onClick={load}>
          Refrescar
        </Button>
      </div>
      {loading ? (
        <Skeleton className="h-64 w-full rounded-xl" />
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>student_name</TableHead>
              <TableHead>student_email</TableHead>
              <TableHead>course_code</TableHead>
              <TableHead>status</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.length === 0 ? (
              <TableRow>
                <TableCell colSpan={4} className="text-center text-muted-foreground">
                  Sin registros
                </TableCell>
              </TableRow>
            ) : (
              rows.map((r) => (
                <TableRow key={r.id}>
                  <TableCell className="font-medium">{r.student_name}</TableCell>
                  <TableCell className="font-mono text-xs">{r.student_email}</TableCell>
                  <TableCell>{r.course_code}</TableCell>
                  <TableCell>
                    <Badge variant="secondary">{r.status}</Badge>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      )}
    </div>
  );
}
