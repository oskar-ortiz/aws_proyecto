"use client";

import * as React from "react";
import { PageHeader } from "@/components/page-header";
import { Card } from "@/components/ui/card";
import { ScrollArea } from "@/components/ui/scroll-area";

const seed = [
  "[deploy] terraform apply completed · outputs written",
  "[lambda] START RequestId: 7f3c2a1b · Version: $LATEST",
  "[asg] EC2 instance i-0abc123 launched in us-east-1a",
  "[nginx] reload signal HUP · upstream 127.0.0.1:8000",
  "[rds] failover test skipped · multi-az healthy",
];

export default function LogsPage() {
  const [lines, setLines] = React.useState<string[]>(() =>
    seed.map((s, i) => `${new Date().toISOString().slice(11, 19)} ${s}`),
  );

  React.useEffect(() => {
    const id = window.setInterval(() => {
      const pick = seed[Math.floor(Math.random() * seed.length)];
      setLines((prev) => {
        const next = [
          ...prev,
          `${new Date().toISOString().slice(11, 19)} ${pick} #${prev.length}`,
        ];
        return next.slice(-80);
      });
    }, 2200);
    return () => window.clearInterval(id);
  }, []);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Logs"
        description="Stream visual simulado estilo terminal. Conecta CloudWatch Logs para trazas reales."
      />
      <Card className="overflow-hidden border-zinc-800 bg-zinc-950 shadow-xl dark:border-zinc-800">
        <div className="flex items-center gap-2 border-b border-zinc-800 px-4 py-2">
          <span className="h-3 w-3 rounded-full bg-red-500/90" />
          <span className="h-3 w-3 rounded-full bg-amber-400/90" />
          <span className="h-3 w-3 rounded-full bg-emerald-500/90" />
          <span className="ml-2 font-mono text-xs text-zinc-500">stream · mock</span>
        </div>
        <ScrollArea className="h-[min(60vh,520px)] p-4">
          <pre className="font-mono text-[11px] leading-relaxed text-emerald-400/95">
            {lines.join("\n")}
          </pre>
        </ScrollArea>
      </Card>
    </div>
  );
}
