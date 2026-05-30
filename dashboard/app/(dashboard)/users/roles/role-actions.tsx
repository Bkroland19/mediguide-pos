"use client"

import { Edit, Trash2, ToggleLeft, Shield } from "lucide-react"
import { RowAction } from "@/types/data-table"
import { Role } from "./types"

/**
 * Factory function to create role row actions with modal handlers
 */
export const createRoleRowActions = (handlers: {
  onEdit: (role: Role) => void
  onDelete: (role: Role) => void
  onToggleStatus: (role: Role) => void
  onManagePermissions: (role: Role) => void
}): RowAction<Role>[] => [
  {
    id: "edit",
    label: "Edit Role",
    icon: Edit,
    onClick: async (role) => {
      handlers.onEdit(role)
    },
  },
  {
    id: "manage-permissions",
    label: "Manage Permissions",
    icon: Shield,
    onClick: async (role) => {
      handlers.onManagePermissions(role)
    },
  },
  {
    id: "toggle-status",
    label: "Toggle Status",
    icon: ToggleLeft,
    onClick: async (role) => {
      handlers.onToggleStatus(role)
    },
  },
  {
    id: "delete",
    label: "Delete Role",
    icon: Trash2,
    variant: "destructive",
    onClick: async (role) => {
      handlers.onDelete(role)
    },
    separator: true,
    confirmMessage: "Are you sure you want to delete this role? This action cannot be undone and may affect users assigned to this role.",
  },
]

// No bulk actions for roles since they are core system entities
// Bulk operations on roles could be dangerous
export const roleBulkActions = []