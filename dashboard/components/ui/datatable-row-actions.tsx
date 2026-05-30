"use client"

import * as React from "react"
import { MoreHorizontal, Loader2 } from "lucide-react"

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
import { BaseRecord, RowAction, DataTableRowActionsProps } from "@/types/data-table"
import { showToast } from "@/lib/toast"

interface DataTableRowActionsComponentProps<TData extends BaseRecord>
  extends DataTableRowActionsProps<TData> {
  size?: "sm" | "default"
  variant?: "ghost" | "outline" | "default"
}

export function DataTableRowActions<TData extends BaseRecord>({
  row,
  actions,
  size = "sm",
  variant = "ghost",
}: DataTableRowActionsComponentProps<TData>) {
  const [loading, setLoading] = React.useState<string | null>(null)
  const [confirmAction, setConfirmAction] = React.useState<RowAction<TData> | null>(null)
  const [isOpen, setIsOpen] = React.useState(false)

  if (actions.length === 0) {
    return null
  }

  const handleAction = async (action: RowAction<TData>) => {
    // Check if action requires confirmation
    if (action.variant === 'destructive' || action.requiresConfirmation) {
      setConfirmAction(action)
      return
    }

    await executeAction(action)
  }

  const executeAction = async (action: RowAction<TData>) => {
    if (action.disabled?.(row)) {
      return
    }

    setLoading(action.id)
    setIsOpen(false)

    try {
      await action.onClick(row)
    } catch (error) {
      const message = error instanceof Error ? error.message : `Failed to ${action.label.toLowerCase()}`
      showToast.error("Error", message)
      console.error(`Action ${action.id} failed:`, error)
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

  // If only one action and it's not destructive, render as a simple button
  if (actions.length === 1 && actions[0].variant !== 'destructive' && !actions[0].requiresConfirmation) {
    const action = actions[0]
    const isDisabled = action.disabled?.(row) || loading === action.id

    return (
      <Button
        variant={action.variant || variant}
        size={size}
        onClick={() => handleAction(action)}
        disabled={isDisabled}
        className="h-8 w-8 p-0"
      >
        {loading === action.id ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : action.icon ? (
          <action.icon className="h-4 w-4" />
        ) : (
          <MoreHorizontal className="h-4 w-4" />
        )}
        <span className="sr-only">{action.label}</span>
      </Button>
    )
  }

  return (
    <>
      <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
        <DropdownMenuTrigger asChild>
          <Button
            variant={variant}
            className="flex h-8 w-8 p-0 data-[state=open]:bg-muted"
            disabled={loading !== null}
          >
            {loading ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <MoreHorizontal className="h-4 w-4" />
            )}
            <span className="sr-only">Open menu</span>
          </Button>
        </DropdownMenuTrigger>
        
        <DropdownMenuContent align="end" className="w-[160px]">
          <DropdownMenuLabel>Actions</DropdownMenuLabel>
          <DropdownMenuSeparator />
          
          {actions.map((action, index) => {
            const isDisabled = action.disabled?.(row) || loading === action.id
            const isLoading = loading === action.id

            return (
              <React.Fragment key={action.id}>
                <DropdownMenuItem
                  onClick={() => handleAction(action)}
                  disabled={isDisabled}
                  className={action.variant === 'destructive' ? 'text-destructive focus:text-destructive' : ''}
                >
                  {isLoading ? (
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  ) : action.icon ? (
                    <action.icon className="mr-2 h-4 w-4" />
                  ) : null}
                  {action.label}
                </DropdownMenuItem>
                
                {action.separator && index < actions.length - 1 && (
                  <DropdownMenuSeparator />
                )}
              </React.Fragment>
            )
          })}
        </DropdownMenuContent>
      </DropdownMenu>

      {/* Confirmation dialog */}
      <AlertDialog open={!!confirmAction} onOpenChange={() => setConfirmAction(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Are you sure?</AlertDialogTitle>
            <AlertDialogDescription>
              {confirmAction?.confirmMessage || 
                `This will ${confirmAction?.label.toLowerCase()} the selected item. This action cannot be undone.`
              }
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

// Utility component for common row actions
interface QuickRowActionsProps<TData extends BaseRecord> {
  row: TData
  onEdit?: (row: TData) => void
  onDelete?: (row: TData) => void
  onView?: (row: TData) => void
  onDuplicate?: (row: TData) => void
  editLabel?: string
  deleteLabel?: string
  viewLabel?: string
  duplicateLabel?: string
  editDisabled?: (row: TData) => boolean
  deleteDisabled?: (row: TData) => boolean
}

export function QuickRowActions<TData extends BaseRecord>({
  row,
  onEdit,
  onDelete,
  onView,
  onDuplicate,
  editLabel = "Edit",
  deleteLabel = "Delete",
  viewLabel = "View",
  duplicateLabel = "Duplicate",
  editDisabled,
  deleteDisabled,
}: QuickRowActionsProps<TData>) {
  const actions: RowAction<TData>[] = []

  if (onView) {
    actions.push({
      id: "view",
      label: viewLabel,
      onClick: onView,
    })
  }

  if (onEdit) {
    actions.push({
      id: "edit",
      label: editLabel,
      onClick: onEdit,
      disabled: editDisabled,
    })
  }

  if (onDuplicate) {
    actions.push({
      id: "duplicate",
      label: duplicateLabel,
      onClick: onDuplicate,
    })
  }

  if (onDelete) {
    if (actions.length > 0) {
      actions[actions.length - 1].separator = true
    }
    
    actions.push({
      id: "delete",
      label: deleteLabel,
      onClick: onDelete,
      variant: "destructive",
      disabled: deleteDisabled,
      confirmMessage: `Are you sure you want to delete this item? This action cannot be undone.`,
    })
  }

  return <DataTableRowActions row={row} actions={actions} />
}

// Hook for building actions dynamically
export function useRowActions<TData extends BaseRecord>() {
  const [actions, setActions] = React.useState<RowAction<TData>[]>([])

  const addAction = React.useCallback((action: RowAction<TData>) => {
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
    onClick: (row: TData) => void | Promise<void>,
    options?: Partial<Omit<RowAction<TData>, 'id' | 'label' | 'onClick'>>
  ): RowAction<TData> => ({
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