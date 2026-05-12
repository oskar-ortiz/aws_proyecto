"use client";

import { cn } from "@/lib/utils";
import { Card } from "@/components/ui/card";

export function ArchitectureFlow() {
  return (
    <div className="mx-auto max-w-3xl space-y-0 rounded-2xl border border-border/80 bg-gradient-to-b from-card via-card to-muted/15 p-6 sm:p-10">
      <div className="flex flex-col items-center">
        <FlowCard title="Internet" subtitle="Usuarios y operadores" />
        <Connector />
        <FlowCard title="ALB público" subtitle="Reglas /admin, /dashboard, /api" highlight />
        <div className="relative flex w-full max-w-lg justify-center gap-4 py-2 sm:gap-8">
          <div className="absolute top-0 hidden h-8 w-px -translate-y-full border-l border-dashed border-primary/40 sm:left-[calc(50%-6rem)] sm:block" />
          <div className="absolute top-0 hidden h-8 w-px -translate-y-full border-l border-dashed border-primary/40 sm:right-[calc(50%-6rem)] sm:block" />
          <div className="flex flex-1 flex-col items-center">
            <div className="mb-2 h-6 w-px border-l border-dashed border-primary/50 sm:hidden" />
            <FlowCard
              title="EC2 Auto Scaling"
              subtitle="NGINX + Flask · /admin"
              className="w-full"
            />
          </div>
          <div className="flex flex-1 flex-col items-center">
            <div className="mb-2 h-6 w-px border-l border-dashed border-primary/50 sm:hidden" />
            <FlowCard
              title="Lambda"
              subtitle="SES · /api/*"
              className="w-full border-amber-500/20 dark:border-amber-400/25"
            />
          </div>
        </div>
        <Connector />
        <FlowCard title="RDS MySQL" subtitle="Writer · Multi-AZ" />
        <Connector />
        <FlowCard
          title="Read Replica"
          subtitle="Réplica de lectura · /admin/enrollments"
          className="border-emerald-500/25"
        />
      </div>
      <p className="mt-8 text-center text-xs text-muted-foreground">
        Flujo ilustrativo · líneas animadas suaves en hover de cada tarjeta
      </p>
    </div>
  );
}

function Connector() {
  return (
    <div
      className="flex h-10 w-px justify-center bg-gradient-to-b from-primary/50 via-primary/30 to-transparent"
      aria-hidden
    >
      <div className="w-0.5 animate-pulse rounded-full bg-primary/60" />
    </div>
  );
}

function FlowCard({
  title,
  subtitle,
  className,
  highlight,
}: {
  title: string;
  subtitle: string;
  className?: string;
  highlight?: boolean;
}) {
  return (
    <Card
      className={cn(
        "w-full max-w-sm border-border/80 bg-card/95 px-5 py-4 shadow-sm backdrop-blur transition-all duration-300 hover:-translate-y-0.5 hover:border-primary/35 hover:shadow-lg",
        highlight && "ring-1 ring-primary/20",
        className,
      )}
    >
      <p className="text-base font-semibold tracking-tight">{title}</p>
      <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{subtitle}</p>
    </Card>
  );
}
