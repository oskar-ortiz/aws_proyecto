import { ArchitectureFlow } from "@/components/architecture-flow";
import { PageHeader } from "@/components/page-header";

export default function ArchitecturePage() {
  return (
    <div>
      <PageHeader
        title="Arquitectura"
        description="Vista lógica del tráfico: Internet, balanceador, cómputo y datos."
      />
      <ArchitectureFlow />
    </div>
  );
}
