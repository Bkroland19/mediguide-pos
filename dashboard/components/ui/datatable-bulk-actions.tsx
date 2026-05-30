"use client"

import * as React from "react"
import { X, ChevronDown, Loader2, AlertTriangle } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Badge } from "@/components/ui/badge"
import { BaseRecord, BulkAction, DataTableBulkActionsProps } from "@/types/data-table"
import { showToast } from "@/lib/toast"

interface DataTableBulkActionsComponentProps<TData extends BaseRecord>
  extends DataTableBulkActionsProps<TData> {
  maxDisplayCount?: number
}

export function DataTableBulkActions<TData extends BaseRecord>({
  selectedRows,
  actions,
  onAction,
  onClearSelection,
  maxDisplayCount = 100,
}: DataTableBulkActionsComponentProps<TData>) {
  const [loading, setLoading] = React.useState<string | null>(null)
  const [confirmAction, setConfirmAction] = React.useState<BulkAction<TData> | null>(null)

  if (selectedRows.length === 0 || actions.length === 0) {
    return null
  }

  const handleAction = async (action: BulkAction<TData>) => {
    if (action.disabled?.(selectedRows)) {
      return
    }

    // Check if action requires confirmation
    if (action.requiresConfirmation || action.variant === 'destructive') {
      setConfirmAction(action)
      return
    }

    await executeAction(action)
  }

  const executeAction = async (action: BulkAction<TData>) => {
    setLoading(action.id)

    try {
      await onAction(action.id, selectedRows)
      showToast.success(
        "Bulk Action Completed",
        `${action.label} applied to ${selectedRows.length} item${selectedRows.length === 1 ? '' : 's'}`
      )
    } catch (error) {
      const message = error instanceof Error 
        ? error.message 
        : `Failed to ${action.label.toLowerCase()}`
      showToast.error("Bulk Action Failed", message)
      console.error(`Bulk action ${action.id} failed:`, error)
    } finally {
      setLoading(null)
    }
  }

  const confirmAndExecute = async () => {
    if (confirmAction) {
      await executeAction(confirmAction)
      setConfirmAction(null)
    }
  }

  const selectedCount = selectedRows.length
  const displayText = selectedCount > maxDisplayCount 
    ? `${maxDisplayCount}+` 
    : selectedCount.toString()

  return (
    <>
      <div className="flex items-center gap-2">
        <div className="flex items-center gap-2 text-sm">
          <Badge variant="secondary" className="text-xs">
            {displayText}
          </Badge>
          <span className="text-muted-foreground">
            {selectedCount === 1 ? 'item' : 'items'} selected
          </span>
        </div>

        <div className="flex items-center gap-1">
          {/* Quick actions (first 2-3 actions shown as buttons) */}
          {actions.slice(0, 2).map((action) => {
            const isDisabled = action.disabled?.(selectedRows) || loading !== null
            const isLoading = loading === action.id

            return (
              <Button
                key={action.id}
                variant={action.variant || "outline"}
                size="sm"
                onClick={() => handleAction(action)}
                disabled={isDisabled}
                className="h-8"
              >
                {isLoading ? (
                  <Loader2 className="mr-1 h-3 w-3 animate-spin" />
                ) : action.icon ? (
                  <action.icon className="mr-1 h-3 w-3" />
                ) : null}
                {action.label}
              </Button>
            )
          })}

          {/* More actions dropdown */}
          {actions.length > 2 && (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="outline"
                  size="sm"
                  className="h-8"
                  disabled={loading !== null}
                >
                  More
                  <ChevronDown className="ml-1 h-3 w-3" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="start">
                <DropdownMenuLabel>Bulk Actions</DropdownMenuLabel>
                <DropdownMenuSeparator />
                
                {actions.slice(2).map((action) => {
                  const isDisabled = action.disabled?.(selectedRows) || loading !== null
                  const isLoading = loading === action.id

                  return (
                    <DropdownMenuItem
                      key={action.id}
                      onClick={() => handleAction(action)}
                      disabled={isDisabled}
                      className={
                        action.variant === 'destructive'
                          ? 'text-destructive focus:text-destructive'
                          : ''
                      }
                    >
                      {isLoading ? (
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      ) : action.icon ? (
                        <action.icon className="mr-2 h-4 w-4" />
                      ) : null}
                      {action.label}
                    </DropdownMenuItem>
                  )
                })}
              </DropdownMenuContent>
            </DropdownMenu>
          )}

          {/* Clear selection */}
          <Button
            variant="ghost"
            size="sm"
            onClick={onClearSelection}
            disabled={loading !== null}
            className="h-8 w-8 p-0"
            title="Clear selection"
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Confirmation dialog */}
      <AlertDialog open={!!confirmAction} onOpenChange={() => setConfirmAction(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2">
              {confirmAction?.variant === 'destructive' && (
                <AlertTriangle className="h-5 w-5 text-destructive" />
              )}
              Confirm Bulk Action
            </AlertDialogTitle>
            <AlertDialogDescription>
              {confirmAction?.confirmMessage || 
                `Are you sure you want to ${confirmAction?.label.toLowerCase()} ${selectedCount} item${selectedCount === 1 ? '' : 's'}?`
              }
              {confirmAction?.variant === 'destructive' && (
                <>
                  <br />
                  <strong className="text-destructive">This action cannot be undone.</strong>
                </>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={confirmAndExecute}
              className={
                confirmAction?.variant === 'destructive'
                  ? "bg-destructive text-destructive-foreground hover:bg-destructive/90"
                  : ""
              }
            >
              {confirmAction?.label || "Continue"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}

// Utility component for common bulk actions
interface QuickBulkActionsProps<TData extends BaseRecord> {
  selectedRows: TData[]
  onBulkDelete?: (rows: TData[]) => Promise<void>
  onBulkEdit?: (rows: TData[]) => Promise<void>
  onBulkExport?: (rows: TData[]) => Promise<void>
  onBulkArchive?: (rows: TData[]) => Promise<void>
  onAction: (actionId: string, rows: TData[]) => Promise<void>
  onClearSelection: () => void
  deleteLabel?: string
  editLabel?: string
  exportLabel?: string
  archiveLabel?: string
}

export function QuickBulkActions<TData extends BaseRecord>({
  selectedRows,
  onBulkDelete,
  onBulkEdit,
  onBulkExport,
  onBulkArchive,
  onAction,
  onClearSelection,
  deleteLabel = "Delete",
  editLabel = "Edit",
  exportLabel = "Export",
  archiveLabel = "Archive",
}: QuickBulkActionsProps<TData>) {
  const actions: BulkAction<TData>[] = []

  if (onBulkEdit) {
    actions.push({
      id: "bulk-edit",
      label: editLabel,
      onClick: onBulkEdit,
      variant: "outline",
    })
  }

  if (onBulkExport) {
    actions.push({
      id: "bulk-export",
      label: exportLabel,
      onClick: onBulkExport,
      variant: "outline",
    })
  }

  if (onBulkArchive) {
    actions.push({
      id: "bulk-archive",
      label: archiveLabel,
      onClick: onBulkArchive,
      variant: "outline",
    })
  }

  if (onBulkDelete) {
    actions.push({
      id: "bulk-delete",
      label: deleteLabel,
      onClick: onBulkDelete,
      variant: "destructive",
      requiresConfirmation: true,
      confirmMessage: `Are you sure you want to delete ${selectedRows.length} item${selectedRows.length === 1 ? '' : 's'}? This action cannot be undone.`,
    })
  }

  return (
    <DataTableBulkActions
      selectedRows={selectedRows}
      actions={actions}
      onAction={onAction}
      onClearSelection={onClearSelection}
    />
  )
}

// Hook for building bulk actions dynamically
export function useBulkActions<TData extends BaseRecord>() {
  const [actions, setActions] = React.useState<BulkAction<TData>[]>([])

  const addAction = React.useCallback((action: BulkAction<TData>) => {
    setActions(prev => [...prev, action])
  }, [])

  const removeAction = React.useCallback((actionId: string) => {
    setActions(prev => prev.filter(action => action.id !== actionId))
  }, [])

  const clearActions = React.useCallback(() => {
    setActions([])
  }, [])

  const buildAction = React.useCallback((
    id: string,
    label: string,
    onClick: (rows: TData[]) => void | Promise<void>,
    options?: Partial<Omit<BulkAction<TData>, 'id' | 'label' | 'onClick'>>
  ): BulkAction<TData> => ({
    id,
    label,
    onClick,
    ...options,
  }), [])

  return {
    actions,
    addAction,
    removeAction,
    clearActions,
    buildAction,
    setActions,
  }
}