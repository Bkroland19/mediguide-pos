"use client"

import * as React from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Plus } from "lucide-react"

// Components
import { PageHeader } from "@/components/ui/page-header"
import { PocketBaseDataTable } from "@/components/ui/pocketbase-datatable-simple"

// Page-specific imports
import { columns, DecisionToolWithRelations } from "./columns"
import { createDecisionToolRowActions, decisionToolBulkActions } from "./decision-tool-actions"
import { decisionToolsAvailableFields } from "./fields"
import { usePermissionContext } from "@/lib/permission-context"

export default function DecisionToolsPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const typeFilter = searchParams.get("type")

  const isCalculatorView = typeFilter === "calculator"
  const { hasPermission, loading } = usePermissionContext()

  React.useEffect(() => {
    if (loading) return
    if (!hasPermission("content", "read:any")) {
      router.replace("/")
    }
  }, [loading, hasPermission, router])

  // Create row actions with navigation dependency injection
  const decisionToolRowActions = React.useMemo(() =>
    createDecisionToolRowActions((path) => router.push(path)),
    [router]
  )

  const pocketbaseOptions = React.useMemo(() => {
    const opts: { expand: string; filter?: string } = { expand: "addedBy" }
    if (typeFilter) {
      opts.filter = `type = "${typeFilter.replace(/"/g, '\\"')}"`
    }
    return opts
  }, [typeFilter])

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <PageHeader
        title={isCalculatorView ? "All Calculators" : "Decision Support Tools"}
        description={
          isCalculatorView
            ? "Every calculator available in the system"
            : "Clinical calculators, decision trees, and assessment tools for healthcare decisions"
        }
        actions={
          isCalculatorView ? [
            {
              label: "Add Calculator",
              onClick: () => router.push('/decision-tools/create'),
              icon: <Plus className="h-4 w-4" />
            }
          ] : [
            {
              label: "Add Decision Tool",
              onClick: () => router.push('/decision-tools/create'),
              icon: <Plus className="h-4 w-4" />
            }
          ]
        }
      />

      {/* Simplified DataTable */}
      <PocketBaseDataTable<DecisionToolWithRelations>
        key={typeFilter ?? "all"}
        collection="calculators"
        columns={columns}
        searchFields={["name", "description", "type", "version"]}
        rowActions={decisionToolRowActions}
        bulkActions={decisionToolBulkActions}
        availableFields={decisionToolsAvailableFields}
        pocketbase={pocketbaseOptions}
        ui={{
          exportable: true
        }}
      />
    </div>
  )
}
