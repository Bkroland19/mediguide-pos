"use client"

import * as React from "react"
import { useRouter } from "next/navigation"
import { Plus } from "lucide-react"

import { PageHeader } from "@/components/ui/page-header"
import { usePermissionContext } from "@/lib/permission-context"
import { FacilityForm } from "../components/facility-form"
import { CreateCountyModal } from "../components/create-county-modal"
import { CreateSubcountyModal } from "../components/create-subcounty-modal"
import { CreateParishModal } from "../components/create-parish-modal"
import { CreateDistrictModal } from "../components/create-district-modal"
import { CreateRegionModal } from "../components/create-region-modal"

export default function CreateFacilityPage() {
  const router = useRouter()
  const { hasPermission, loading } = usePermissionContext()

  React.useEffect(() => {
    if (loading) return
    if (!hasPermission("content", "create:any")) {
      router.replace("/health-facilities")
    }
  }, [loading, hasPermission, router])

  const [showCountyModal, setShowCountyModal] = React.useState(false)
  const [showSubcountyModal, setShowSubcountyModal] = React.useState(false)
  const [showParishModal, setShowParishModal] = React.useState(false)
  const [showDistrictModal, setShowDistrictModal] = React.useState(false)
  const [showRegionModal, setShowRegionModal] = React.useState(false)

  return (
    <div className="space-y-6">
      <PageHeader
        title="Add Health Facility"
        description="Create a new health facility in the system"
        showBackButton={true}
        onBack={() => window.history.back()}
        actions={[
          {
            label: "Create Location",
            onClick: () => {},
            icon: <Plus className="h-4 w-4" />,
            variant: "outline",
            dropdownItems: [
              {
                label: "Create Region",
                onClick: () => setShowRegionModal(true)
              },
              {
                label: "Create District", 
                onClick: () => setShowDistrictModal(true)
              },
              {
                label: "Create County",
                onClick: () => setShowCountyModal(true)
              },
              {
                label: "Create Subcounty",
                onClick: () => setShowSubcountyModal(true)
              },
              {
                label: "Create Parish",
                onClick: () => setShowParishModal(true)
              }
            ]
          }
        ]}
      />

      <FacilityForm mode="create" />

      {/* Administrative Entity Creation Modals */}
      <CreateRegionModal 
        open={showRegionModal} 
        onClose={() => setShowRegionModal(false)}
      />
      <CreateDistrictModal 
        open={showDistrictModal} 
        onClose={() => setShowDistrictModal(false)}
      />
      <CreateCountyModal 
        open={showCountyModal} 
        onClose={() => setShowCountyModal(false)}
      />
      <CreateSubcountyModal 
        open={showSubcountyModal} 
        onClose={() => setShowSubcountyModal(false)}
      />
      <CreateParishModal 
        open={showParishModal} 
        onClose={() => setShowParishModal(false)}
      />
    </div>
  )
}