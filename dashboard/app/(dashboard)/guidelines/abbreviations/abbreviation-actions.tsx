import { RowAction, BulkAction } from "@/types/data-table"
import { AbbreviationsWithExpanded } from "@/types/expanded"
import { Eye, Edit, Trash2, Copy, Download, Tag } from "lucide-react"

/**
 * Row actions for abbreviations table
 * Factory pattern for dependency injection
 */
export const createAbbreviationRowActions = (
  onEdit: (abbreviation: AbbreviationsWithExpanded) => void,
  onView: (abbreviation: AbbreviationsWithExpanded) => void
): RowAction<AbbreviationsWithExpanded>[] => [
  {
    id: "view",
    label: "View Details",
    icon: Eye,
    onClick: onView,
  },
  {
    id: "edit",
    label: "Edit Abbreviation",
    icon: Edit,
    onClick: onEdit,
  },
  {
    id: "copy",
    label: "Copy Text",
    icon: Copy,
    onClick: async (abbreviation) => {
      const text = `${abbreviation.abbreviation}: ${abbreviation.meaning}`
      await navigator.clipboard.writeText(text)
    },
    separator: true,
  },
  {
    id: "delete",
    label: "Delete Abbreviation",
    icon: Trash2,
    variant: "destructive",
    onClick: async (abbreviation) => {
      // Delete logic will be handled by the data table
      console.log("Deleting abbreviation:", abbreviation.id)
    },
    confirmMessage: "Are you sure you want to delete this abbreviation? This action cannot be undone.",
    separator: true,
  },
]

/**
 * Bulk actions for abbreviations table
 */
export const abbreviationBulkActions: BulkAction<AbbreviationsWithExpanded>[] = [
  {
    id: "bulk-common",
    label: "Mark as Common Usage",
    icon: Tag,
    onClick: async (abbreviations) => {
      // Update common_usage field for selected items
      console.log("Marking as common usage:", abbreviations.length, "items")
    },
    description: "Mark selected abbreviations as commonly used",
  },
  {
    id: "bulk-uncommon",
    label: "Mark as Standard Usage",
    icon: Tag,
    variant: "outline",
    onClick: async (abbreviations) => {
      // Update common_usage field for selected items
      console.log("Marking as standard usage:", abbreviations.length, "items")
    },
    description: "Mark selected abbreviations as standard usage",
  },
  {
    id: "bulk-export",
    label: "Export Selected",
    icon: Download,
    onClick: async (abbreviations) => {
      // Export selected abbreviations
      const csvContent = [
        "Abbreviation,Meaning,Description,Common Usage,Category",
        ...abbreviations.map(item => [
          item.abbreviation,
          item.meaning,
          item.description || "",
          item.common_usage ? "Yes" : "No",
          item.expand?.category?.name || ""
        ].join(","))
      ].join("\\n")
      
      const blob = new Blob([csvContent], { type: "text/csv" })
      const url = URL.createObjectURL(blob)
      const a = document.createElement("a")
      a.href = url
      a.download = "abbreviations.csv"
      a.click()
      URL.revokeObjectURL(url)
    },
    description: "Download selected abbreviations as CSV",
    separator: true,
  },
  {
    id: "bulk-delete",
    label: "Delete Selected",
    icon: Trash2,
    variant: "destructive",
    onClick: async (abbreviations) => {
      // Delete logic will be handled by the data table
      console.log("Deleting abbreviations:", abbreviations.length, "items")
    },
    disabled: (abbreviations) => abbreviations.length === 0,
    description: "Delete selected abbreviations permanently",
    requiresConfirmation: true,
    separator: true,
  },
]