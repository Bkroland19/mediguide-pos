/**
 * Permission Context Provider
 * React context for managing user permissions throughout the application
 */

"use client"

import * as React from 'react'
import { usePermissions } from '@/hooks/use-permissions'
import type {
  PermissionContextValue,
  PermissionAction
} from '@/types/permissions'

const PermissionContext = React.createContext<PermissionContextValue | null>(null)

interface PermissionProviderProps {
  children: React.ReactNode
  userRole?: string
  disabled?: boolean
}

/**
 * Permission Provider Component
 */
export function PermissionProvider({
  children,
  userRole,
  disabled = false
}: PermissionProviderProps) {
  const permissionHook = usePermissions({
    currentUserRole: userRole,
    autoInitialize: !disabled
  })

  const contextValue: PermissionContextValue = React.useMemo(() => ({
    permissions: userRole && permissionHook.initialized
      ? permissionHook.getEffectivePermissions(userRole)
      : {},
    hasPermission: (resource: string, action: PermissionAction, _attributes?: string[]) => {
      if (disabled || !userRole) return false
      // _attributes parameter reserved for future use
      void _attributes;
      return permissionHook.hasPermission(resource, action)
    },
    checkPermission: (resource: string, action: PermissionAction) => {
      if (disabled || !userRole) {
        return { granted: false, attributes: [], filter: (data) => data }
      }
      return permissionHook.checkPermission(resource, action)
    },
    filterData: (resource: string, action: PermissionAction, data: unknown) => {
      if (disabled || !userRole) return data
      const permission = permissionHook.checkPermission(resource, action)
      return permission.granted ? permission.filter(data) : null
    },
    loading: permissionHook.loading || !permissionHook.initialized,
    error: permissionHook.error
  }), [
    permissionHook,
    userRole,
    disabled
  ])

  return (
    <PermissionContext.Provider value={contextValue}>
      {children}
    </PermissionContext.Provider>
  )
}

/**
 * Hook to access permission context
 */
export function usePermissionContext(): PermissionContextValue {
  const context = React.useContext(PermissionContext)

  if (!context) {
    throw new Error('usePermissionContext must be used within a PermissionProvider')
  }

  return context
}

/**
 * Higher-order component for permission-based rendering
 */
interface WithPermissionProps {
  children: React.ReactNode
  resource: string
  action: PermissionAction
  fallback?: React.ReactNode
  loading?: React.ReactNode
}

export function WithPermission({
  children,
  resource,
  action,
  fallback = null,
  loading = null
}: WithPermissionProps) {
  const { hasPermission, loading: permissionLoading } = usePermissionContext()

  if (permissionLoading) {
    return <>{loading}</>
  }

  if (!hasPermission(resource, action)) {
    return <>{fallback}</>
  }

  return <>{children}</>
}

/**
 * Hook for permission-based conditional rendering
 */
export function usePermissionGuard(resource: string, action: PermissionAction) {
  const { hasPermission, loading, error } = usePermissionContext()

  return React.useMemo(() => ({
    allowed: hasPermission(resource, action),
    loading,
    error
  }), [hasPermission, resource, action, loading, error])
}

/**
 * Hook for filtering data based on permissions
 */
export function usePermissionFilter<T = unknown>(
  resource: string,
  action: PermissionAction
) {
  const { checkPermission, loading } = usePermissionContext()

  const filterData = React.useCallback((data: T | T[]): T | T[] | null => {
    if (loading) return data

    const permission = checkPermission(resource, action)

    if (!permission.granted) {
      return null
    }

    return permission.filter(data)
  }, [checkPermission, resource, action, loading])

  return { filterData, loading }
}

/**
 * Permission Gate Component
 * Shows different content based on permission level
 */
interface PermissionGateProps {
  children: React.ReactNode
  resource: string
  actions: {
    [K in 'read' | 'create' | 'update' | 'delete']?: {
      own?: React.ReactNode
      any?: React.ReactNode
    }
  }
  fallback?: React.ReactNode
}

export function PermissionGate({
  children,
  resource,
  actions,
  fallback = null
}: PermissionGateProps) {
  const { hasPermission } = usePermissionContext()

  // Check for any level of access first
  const hasAnyAccess = Object.entries(actions).some(([actionType, levels]) => {
    const typedActionType = actionType as keyof typeof actions
    const actionLevels = levels as { own?: React.ReactNode; any?: React.ReactNode }

    return (
      (actionLevels.any && hasPermission(resource, `${typedActionType}:any` as PermissionAction)) ||
      (actionLevels.own && hasPermission(resource, `${typedActionType}:own` as PermissionAction))
    )
  })

  if (!hasAnyAccess) {
    return <>{fallback}</>
  }

  // Render specific content based on permission level
  for (const [actionType, levels] of Object.entries(actions)) {
    const typedActionType = actionType as keyof typeof actions
    const actionLevels = levels as { own?: React.ReactNode; any?: React.ReactNode }

    // Check for 'any' level first (higher permission)
    if (actionLevels.any && hasPermission(resource, `${typedActionType}:any` as PermissionAction)) {
      return <>{actionLevels.any}</>
    }

    // Then check for 'own' level
    if (actionLevels.own && hasPermission(resource, `${typedActionType}:own` as PermissionAction)) {
      return <>{actionLevels.own}</>
    }
  }

  // Default to showing children if no specific action content is defined
  return <>{children}</>
}

/**
 * Component for debugging permissions in development
 */
interface PermissionDebugProps {
  resource?: string
  action?: PermissionAction
  className?: string
}

export function PermissionDebug({
  resource,
  action,
  className = "fixed bottom-4 right-4 p-2 bg-black/80 text-white text-xs rounded z-50"
}: PermissionDebugProps) {
  const { permissions, hasPermission, loading, error } = usePermissionContext()

  // Only show in development
  if (process.env.NODE_ENV !== 'development') {
    return null
  }

  const debugInfo = {
    loading,
    error: error?.message,
    hasPermission: resource && action ? hasPermission(resource, action) : 'N/A',
    permissions: Object.keys(permissions).length,
    details: resource ? permissions[resource] : 'No resource specified'
  }

  return (
    <div className={className}>
      <div className="font-mono text-xs">
        <div>Permission Debug</div>
        <div>Resource: {resource || 'None'}</div>
        <div>Action: {action || 'None'}</div>
        <div>Allowed: {String(debugInfo.hasPermission)}</div>
        <div>Loading: {String(debugInfo.loading)}</div>
        {debugInfo.error && <div className="text-red-400">Error: {debugInfo.error}</div>}
      </div>
    </div>
  )
}

/**
 * Utility hook for common permission patterns
 */
export function useCommonPermissions() {
  const { hasPermission } = usePermissionContext()

  return React.useMemo(() => ({
    // User management permissions
    canManageUsers: hasPermission('users', 'create:any') || hasPermission('users', 'update:any'),
    canViewUsers: hasPermission('users', 'read:any') || hasPermission('users', 'read:own'),
    canDeleteUsers: hasPermission('users', 'delete:any'),

    // Role management permissions
    canManageRoles: hasPermission('roles', 'create:any') || hasPermission('roles', 'update:any'),
    canViewRoles: hasPermission('roles', 'read:any'),

    // Content management permissions
    canManageContent: hasPermission('content', 'create:any') || hasPermission('content', 'update:any'),
    canViewContent: hasPermission('content', 'read:any') || hasPermission('content', 'read:own'),
    canPublishContent: hasPermission('content', 'update:any'),

    // System permissions
    canViewReports: hasPermission('reports', 'read:any'),
    canAccessSystemSettings: hasPermission('system_settings', 'read:any'),
    canViewAuditLogs: hasPermission('audit_logs', 'read:any'),

    // Helper function for custom checks
    can: hasPermission
  }), [hasPermission])
}