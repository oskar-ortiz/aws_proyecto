"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Activity,
  ClipboardList,
  Cloud,
  FileText,
  Gauge,
  LayoutDashboard,
  Mail,
  Menu,
  Network,
  ScrollText,
  Server,
  Table2,
  Zap,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { ModeToggle } from "@/components/mode-toggle";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { TooltipProvider } from "@/components/ui/tooltip";

const nav = [
  { href: "/", label: "Overview", icon: LayoutDashboard },
  { href: "/architecture/", label: "Arquitectura", icon: Network },
  { href: "/services/", label: "Servicios AWS", icon: Cloud },
  { href: "/system/", label: "Estado del sistema", icon: Activity },
  { href: "/metrics/", label: "Métricas", icon: Gauge },
  { href: "/autoscaling/", label: "Auto Scaling", icon: Zap },
  { href: "/rds/", label: "RDS Health", icon: Server },
  { href: "/ses/", label: "SES / Email", icon: Mail },
  { href: "/tests/", label: "Pruebas", icon: ScrollText },
  { href: "/logs/", label: "Logs", icon: FileText },
  { href: "/enrollments/", label: "Matrículas", icon: Table2 },
  { href: "/evidence/", label: "Evidencias", icon: ClipboardList },
] as const;

function NavLinks({ className }: { className?: string }) {
  const pathname = usePathname();
  return (
    <nav className={cn("flex flex-col gap-0.5 p-2", className)}>
      {nav.map(({ href, label, icon: Icon }) => {
        const norm = (pathname || "/").replace(/\/$/, "") || "/";
        const h = href.replace(/\/$/, "") || "/";
        const active =
          h === "/" ? norm === "/" : norm === h || norm.startsWith(`${h}/`);
        return (
          <Link
            key={href}
            href={href}
            className={cn(
              "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
              active
                ? "bg-primary/10 text-primary"
                : "text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            <Icon className="h-4 w-4 shrink-0 opacity-80" />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}

export function DashboardShell({ children }: { children: React.ReactNode }) {
  return (
    <TooltipProvider delayDuration={200}>
      <div className="flex min-h-screen w-full bg-background">
        <aside className="hidden w-60 shrink-0 border-r border-border/80 bg-card/30 lg:flex lg:flex-col">
          <div className="flex h-14 items-center border-b border-border/80 px-4">
            <div className="flex flex-col">
              <span className="text-sm font-semibold tracking-tight">
                Cloud Control
              </span>
              <span className="text-[10px] uppercase tracking-widest text-muted-foreground">
                University
              </span>
            </div>
          </div>
          <ScrollArea className="flex-1 py-2">
            <NavLinks />
          </ScrollArea>
          <div className="border-t border-border/80 p-3 text-[10px] text-muted-foreground">
            Rutas relativas · /admin · /api
          </div>
        </aside>

        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-40 flex h-14 items-center gap-2 border-b border-border/80 bg-background/80 px-3 backdrop-blur-md sm:px-4">
            <Sheet>
              <SheetTrigger asChild>
                <Button variant="ghost" size="icon" className="lg:hidden">
                  <Menu className="h-5 w-5" />
                  <span className="sr-only">Menú</span>
                </Button>
              </SheetTrigger>
              <SheetContent side="left" className="w-64 p-0">
                <SheetHeader className="border-b border-border p-4 text-left">
                  <SheetTitle>Navegación</SheetTitle>
                </SheetHeader>
                <ScrollArea className="h-[calc(100vh-5rem)]">
                  <NavLinks />
                </ScrollArea>
              </SheetContent>
            </Sheet>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-foreground">
                Panel operativo
              </p>
              <p className="truncate text-xs text-muted-foreground">
                ALB → EC2 / Lambda · RDS · SES
              </p>
            </div>
            <ModeToggle />
          </header>
          <Separator className="opacity-50" />
          <main className="flex-1 p-4 sm:p-6 lg:p-8">{children}</main>
        </div>
      </div>
    </TooltipProvider>
  );
}
