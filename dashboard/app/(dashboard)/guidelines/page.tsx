"use client"

import * as React from "react"
import { Plus } from "lucide-react"
import { useRouter } from "next/navigation"
import { useQueryClient } from "@tanstack/react-query"

// Components
import { PageHeader } from "@/components/ui/page-header"
import { PocketBaseDataTable } from "@/components/ui/pocketbase-datatable-simple"

// Page-specific imports
import { guidelinesColumns, MedicalGuidelineType } from "./columns"
import { createGuidelineRowActions, createGuidelineBulkActions } from "./guideline-actions"
import { medicalGuidelinesAvailableFields } from "./fields"
import { AssignIndexModal } from "./components/assign-index-modal"
import { GuidelineVersionManager } from "./components/guideline-version-manager"
import { MedicalGuidelinesWithExpanded } from "@/types/expanded"
import { usePermissionContext } from "@/lib/permission-context"

export default function GuidelinesPage() {
  const router = useRouter()
  const queryClient = useQueryClient()

  const { hasPermission, loading } = usePermissionContext()

  React.useEffect(() => {
    if (loading) return
    if (!hasPermission("content", "read:any")) {
      router.replace("/")
    }
  }, [loading, hasPermission, router])
  
  // Modal state
  const [assignIndexModalOpen, setAssignIndexModalOpen] = React.useState(false)
  const [selectedGuideline, setSelectedGuideline] = React.useState<MedicalGuidelinesWithExpanded | null>(null)
  const [refreshKey, setRefreshKey] = React.useState(0)

  // Handle assign index modal
  const handleAssignIndex = React.useCallback((guideline: MedicalGuidelinesWithExpanded) => {
    setSelectedGuideline(guideline)
    setAssignIndexModalOpen(true)
  }, [])

  // After any guideline mutation (publish toggle, archive, delete, bulk), drop the
  // list cache so the table refetches the latest rows.
  const handleMutationSuccess = React.useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: ["pb", "medical_guidelines"] })
  }, [queryClient])

  const handleModalSuccess = React.useCallback(() => {
    setRefreshKey(prev => prev + 1)
  }, [])

  // Create row actions with navigation and modal handlers
  const guidelineRowActions = React.useMemo(
    () =>
      createGuidelineRowActions({
        navigate: (path) => router.push(path),
        onAssignIndex: handleAssignIndex,
        onMutationSuccess: handleMutationSuccess,
      }),
    [router, handleAssignIndex, handleMutationSuccess]
  )

  const guidelineBulkActions = React.useMemo(
    () => createGuidelineBulkActions({ onMutationSuccess: handleMutationSuccess }),
    [handleMutationSuccess]
  )

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <PageHeader
        title="Medical Guidelines"
        description="Comprehensive clinical guidelines and treatment protocols for health workers"
        actions={hasPermission("content", "create:any") ? [
          {
            label: "Create Guideline",
            onClick: () => router.push('/guidelines/create'),
            icon: <Plus className="h-4 w-4" />
          }
        ] : []}
      />

      <GuidelineVersionManager />

      {/* Simplified DataTable */}
      <PocketBaseDataTable<MedicalGuidelineType>
        collection="medical_guidelines"
        columns={guidelinesColumns}
        searchFields={["condition_name", "icd10_code", "target_population"]}
        rowActions={guidelineRowActions}
        bulkActions={guidelineBulkActions}
        availableFields={medicalGuidelinesAvailableFields}
        pocketbase={{
          expand: "categories,tags,index_item",
          fields: "id,condition_name,icd10_code,target_population,medication_primary,medication_secondary,healthcare_level_required,route_administration,status,is_published,priority,version,created,updated,categories,tags,index_item,usageCount,expand.categories.id,expand.categories.name,expand.tags.id,expand.tags.name,expand.index_item.id,expand.index_item.title"
        }}
        ui={{
          exportable: true
        }}
        key={refreshKey}
      />

      {/* Assign Index Modal */}
      <AssignIndexModal
        open={assignIndexModalOpen}
        onOpenChange={setAssignIndexModalOpen}
        guideline={selectedGuideline}
        onSuccess={handleModalSuccess}
      />
    </div>
  )
}
