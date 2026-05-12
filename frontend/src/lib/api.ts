import type { DashboardContext, EnrollmentsResponse } from "@/lib/types";

export async function fetchDashboardContext(): Promise<DashboardContext | null> {
  try {
    const res = await fetch("/admin/dashboard-context", {
      cache: "no-store",
      credentials: "same-origin",
    });
    if (!res.ok) return null;
    return (await res.json()) as DashboardContext;
  } catch {
    return null;
  }
}

export async function fetchEnrollments(): Promise<EnrollmentsResponse | null> {
  try {
    const res = await fetch("/admin/enrollments", {
      cache: "no-store",
      credentials: "same-origin",
    });
    if (!res.ok) return null;
    return (await res.json()) as EnrollmentsResponse;
  } catch {
    return null;
  }
}

export async function createEnrollment(body: {
  student_name: string;
  student_email: string;
  course_code: string;
}): Promise<{ ok: boolean; status: number; json: unknown }> {
  const res = await fetch("/admin/enrollments", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "same-origin",
    body: JSON.stringify(body),
  });
  let json: unknown = null;
  try {
    json = await res.json();
  } catch {
    /* empty */
  }
  return { ok: res.ok, status: res.status, json };
}

export async function postSesTest(payload: {
  enrollment_id?: number;
  student_email: string;
  student_name: string;
  course_code: string;
}): Promise<{ ok: boolean; status: number; json: unknown }> {
  const res = await fetch("/api/confirm", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "same-origin",
    body: JSON.stringify(payload),
  });
  let json: unknown = null;
  try {
    json = await res.json();
  } catch {
    /* empty */
  }
  return { ok: res.ok, status: res.status, json };
}
