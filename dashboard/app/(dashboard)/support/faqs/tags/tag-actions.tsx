import type { RowAction, BulkAction } from "@/types/data-table"
import type { FaqTagWithStats } from "@/types/faq"
import { 
  Edit, 
  Eye, 
  Trash2, 
  CheckCircle, 
  XCircle,
  GitMerge,
  RotateCcw,
  Shield
} from "lucide-react"
import { showToast } from "@/lib/toast"
import { FaqTagsService } from "@/services/faq-tags.service"

/**
 * Factory function for FAQ tag row actions
 * Uses dependency injection pattern for navigation
 */
export const createTagRowActions = (navigate: (path: string) => void): RowAction<FaqTagWithStats>[] => [
  {
    id: "view-faqs",
    label: "View FAQs",
    icon: Eye,
    onClick: async (tag) => {
      // Navigate to main FAQ page with tag filter
      navigate(`/support/faqs?tag=${tag.id}`)
    },
    disabled: (tag) => (tag.usage_count || 0) === 0,
  },
  {
    id: "edit",
    label: "Edit Tag",
    icon: Edit,
    onClick: async (tag) => {
      navigate(`/support/faqs/tags/${tag.id}/edit`)
    },
  },
  {
    id: "toggle-status", 
    label: "Toggle Status",
    icon: Shield,
    onClick: async (tag) => {
      try {
        const result = await FaqTagsService.updateTag(tag.id, {
          is_active: !tag.is_active
        })
        if (result.success) {
          const action = tag.is_active ? "deactivated" : "activated"
          showToast.success("Success", `Tag ${action}`)
        } else {
          showToast.error("Error", result.error || "Failed to update tag")
        }
      } catch (error: unknown) {
        console.error('Error updating tag status:', error)
        showToast.error("Error", "Failed to update tag")
      }
    },
    separator: true,
  },
  {
    id: "delete",
    label: "Delete Tag",
    icon: Trash2,
    variant: "destructive",
    onClick: async (tag) => {
      try {
        const usageCount = tag.usage_count || tag.faq_count || 0
        const force = usageCount > 0
        
        if (force) {
          // Show additional confirmation for tags in use
          const confirmed = confirm(
            `This tag is used by ${usageCount} FAQ${usageCount > 1 ? 's' : ''}. ` +
            `Deleting it will remove it from all FAQs. Are you sure?`
          )
          if (!confirmed) return
        }
        
        const result = await FaqTagsService.deleteTag(tag.id, force)
        if (result.success) {
          showToast.success("Success", result.message || "Tag deleted successfully")
        } else {
          showToast.error("Error", result.error || "Failed to delete tag")
        }
      } catch (error: unknown) {
        console.error('Error deleting tag:', error)
        showToast.error("Error", "Failed to delete tag")
      }
    },
    confirmMessage: "Are you sure you want to delete this tag? This action cannot be undone.",
  },
]

/**
 * Bulk actions for selected tags
 */
export const tagBulkActions: BulkAction<FaqTagWithStats>[] = [
  {
    id: "bulk-activate",
    label: "Activate Selected",
    icon: CheckCircle,
    onClick: async (tags) => {
      try {
        const ids = tags.map(tag => tag.id)
        const result = await FaqTagsService.bulkUpdateStatus(ids, true)
        if (result.success && result.data) {
          const { success_count, error_count } = result.data
          if (error_count > 0) {
            showToast.warning("Partial Success", 
              `Activated ${success_count} tags, ${error_count} failed`)
          } else {
            showToast.success("Success", `Activated ${success_count} tags`)
          }
        } else {
          showToast.error("Error", result.error || "Failed to activate tags")
        }
      } catch (error: unknown) {
        console.error('Error activating tags:', error)
        showToast.error("Error", "Failed to activate tags")
      }
    },
    disabled: (tags) => tags.every(tag => tag.is_active),
    description: "Activate all selected tags",
  },
  {
    id: "bulk-deactivate",
    label: "Deactivate Selected",
    icon: XCircle,
    onClick: async (tags) => {
      try {
        const ids = tags.map(tag => tag.id)
        const result = await FaqTagsService.bulkUpdateStatus(ids, false)
        if (result.success && result.data) {
          const { success_count, error_count } = result.data
          if (error_count > 0) {
            showToast.warning("Partial Success", 
              `Deactivated ${success_count} tags, ${error_count} failed`)
          } else {
            showToast.success("Success", `Deactivated ${success_count} tags`)
          }
        } else {
          showToast.error("Error", result.error || "Failed to deactivate tags")
        }
      } catch (error: unknown) {
        console.error('Error deactivating tags:', error)
        showToast.error("Error", "Failed to deactivate tags")
      }
    },
    disabled: (tags) => tags.every(tag => !tag.is_active),
    variant: "outline",
    description: "Deactivate all selected tags",
  },
  {
    id: "bulk-merge",
    label: "Merge Tags",
    icon: GitMerge,
    onClick: async (tags) => {
      if (tags.length < 2) {
        showToast.error("Error", "Select at least 2 tags to merge")
        return
      }
      
      // Find the tag with highest usage count as merge target
      const sortedTags = [...tags].sort((a, b) => 
        (b.usage_count || b.faq_count || 0) - (a.usage_count || a.faq_count || 0)
      )
      const targetTag = sortedTags[0]
      const sourceTags = sortedTags.slice(1)
      
      const confirmed = confirm(
        `Merge ${sourceTags.length} tags into "${targetTag.name}"? ` +
        `This will move all FAQ associations and delete the source tags. ` +
        `This action cannot be undone.`
      )
      
      if (!confirmed) return
      
      try {
        const sourceIds = sourceTags.map(tag => tag.id)
        const result = await FaqTagsService.mergeTags(sourceIds, targetTag.id)
        
        if (result.success && result.data) {
          const { success_count, error_count } = result.data
          if (error_count > 0) {
            showToast.warning("Partial Success", 
              `Merged ${success_count} tags, ${error_count} failed`)
          } else {
            showToast.success("Success", result.message || `Merged ${success_count} tags into "${targetTag.name}"`)
          }
        } else {
          showToast.error("Error", result.error || "Failed to merge tags")
        }
      } catch (error: unknown) {
        console.error('Error merging tags:', error)
        showToast.error("Error", "Failed to merge tags")
      }
    },
    variant: "outline",
    description: "Merge selected tags into the most used one",
    separator: true,
  },
  {
    id: "bulk-recalculate",
    label: "Recalculate Usage",
    icon: RotateCcw,
    onClick: async () => {
      try {
        const result = await FaqTagsService.recalculateUsageCounts()
        if (result.success && result.data) {
          showToast.success("Success", 
            `Recalculated usage counts for ${result.data.updated} tags`)
        } else {
          showToast.error("Error", result.error || "Failed to recalculate")
        }
      } catch (error: unknown) {
        console.error('Error recalculating usage counts:', error)
        showToast.error("Error", "Failed to recalculate usage counts")
      }
    },
    variant: "outline",
    description: "Fix and recalculate usage counts for all tags",
  },
]