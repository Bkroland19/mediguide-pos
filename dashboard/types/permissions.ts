/**
 * Permission System Types
 * Based on AccessControl library for granular role-based access control
 */

import { Query } from 'accesscontrol'

// System Resources - Define all resources that can be controlled
export interface SystemResource {
  key: string
  name: string
  description?: string
  fields: string[]
}

// Available Actions in the system
export type PermissionAction = 
  | 'create:own' 
  | 'create:any'
  | 'read:own'
  | 'read:any'
  | 'update:own'
  | 'update:any'
  | 'delete:own'
  | 'delete:any'

// Permission Grant Structure (matches AccessControl format)
export interface PermissionGrant {
  role: string
  resource: string
  action: PermissionAction
  attributes: string[] | string
}

// Role Permission Configuration
export interface RolePermissions {
  [resource: string]: {
    [action: string]: string[] // attributes
  }
}

// Permission Check Result
export interface PermissionCheck {
  granted: boolean
  attributes: string[]
  filter: (data: any) => any
}

// Permission Builder State
export interface PermissionBuilderState {
  [resource: string]: {
    [action: string]: {
      granted: boolean
      attributes: string[]
    }
  }
}

// System Resources Definition
export const SYSTEM_RESOURCES: Record<string, SystemResource> = {
  users: {
    key: 'users',
    name: 'Users',
    description: 'Healthcare workers and system users',
    fields: [
      'id', 'name', 'email', 'phone', 'role', 'status', 
      'organization', 'department', 'jobTitle', 'specialization',
      'verified', 'avatar', 'notes', 'created', 'updated',
      'password', 'tokenKey' // sensitive fields
    ]
  },
  roles: {
    key: 'roles',
    name: 'Roles',
    description: 'System roles and permissions',
    fields: [
      'id', 'name', 'key', 'description', 'permissions', 
      'isActive', 'created', 'updated'
    ]
  },
  content: {
    key: 'content',
    name: 'Content',
    description: 'Medical guidelines and protocols',
    fields: [
      'id', 'title', 'body', 'author', 'status', 'category',
      'tags', 'version', 'created', 'updated'
    ]
  },
  reports: {
    key: 'reports',
    name: 'Reports',
    description: 'System reports and analytics',
    fields: [
      'id', 'type', 'title', 'data', 'generated_by',
      'parameters', 'created', 'updated'
    ]
  },
  system_settings: {
    key: 'system_settings',
    name: 'System Settings',
    description: 'Application configuration and settings',
    fields: ['*'] // All fields
  },
  audit_logs: {
    key: 'audit_logs',
    name: 'Audit Logs',
    description: 'System activity and audit trails',
    fields: [
      'id', 'action', 'resource', 'user_id', 'details',
      'ip_address', 'user_agent', 'created'
    ]
  }
}

// Permission Actions with Human-Readable Labels
export const PERMISSION_ACTIONS: Record<PermissionAction, string> = {
  'create:own': 'Create Own',
  'create:any': 'Create Any',
  'read:own': 'Read Own',
  'read:any': 'Read Any', 
  'update:own': 'Update Own',
  'update:any': 'Update Any',
  'delete:own': 'Delete Own',
  'delete:any': 'Delete Any'
}

// Grouped Actions for UI
export const ACTION_GROUPS = {
  create: ['create:own', 'create:any'] as PermissionAction[],
  read: ['read:own', 'read:any'] as PermissionAction[],
  update: ['update:own', 'update:any'] as PermissionAction[],
  delete: ['delete:own', 'delete:any'] as PermissionAction[]
}

// Default Permission Templates for Common Roles
export const PERMISSION_TEMPLATES: Record<string, PermissionGrant[]> = {
  super_admin: [
    // Apply full permissions to all system resources
    { role: 'super_admin', resource: 'users', action: 'create:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'users', action: 'read:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'users', action: 'update:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'users', action: 'delete:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'roles', action: 'create:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'roles', action: 'read:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'roles', action: 'update:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'roles', action: 'delete:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'content', action: 'create:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'content', action: 'read:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'content', action: 'update:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'content', action: 'delete:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'reports', action: 'create:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'reports', action: 'read:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'reports', action: 'update:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'reports', action: 'delete:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'system_settings', action: 'read:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'system_settings', action: 'update:any', attributes: ['*'] },
    { role: 'super_admin', resource: 'audit_logs', action: 'read:any', attributes: ['*'] }
  ],
  admin: [
    { role: 'admin', resource: 'users', action: 'create:any', attributes: ['*', '!password'] },
    { role: 'admin', resource: 'users', action: 'read:any', attributes: ['*', '!password', '!tokenKey'] },
    { role: 'admin', resource: 'users', action: 'update:any', attributes: ['*', '!password'] },
    { role: 'admin', resource: 'users', action: 'delete:any', attributes: ['*'] },
    { role: 'admin', resource: 'roles', action: 'read:any', attributes: ['*'] },
    { role: 'admin', resource: 'content', action: 'create:any', attributes: ['*'] },
    { role: 'admin', resource: 'content', action: 'read:any', attributes: ['*'] },
    { role: 'admin', resource: 'content', action: 'update:any', attributes: ['*'] },
    { role: 'admin', resource: 'content', action: 'delete:any', attributes: ['*'] },
    { role: 'admin', resource: 'reports', action: 'create:any', attributes: ['*'] },
    { role: 'admin', resource: 'reports', action: 'read:any', attributes: ['*'] },
    { role: 'admin', resource: 'system_settings', action: 'read:any', attributes: ['*'] },
    { role: 'admin', resource: 'system_settings', action: 'update:any', attributes: ['*'] },
    { role: 'admin', resource: 'audit_logs', action: 'read:any', attributes: ['*'] }
  ],
  content_manager: [
    { role: 'content_manager', resource: 'users', action: 'read:any', attributes: ['name', 'email', 'role', 'organization'] },
    { role: 'content_manager', resource: 'content', action: 'create:any', attributes: ['*'] },
    { role: 'content_manager', resource: 'content', action: 'read:any', attributes: ['*'] },
    { role: 'content_manager', resource: 'content', action: 'update:any', attributes: ['*'] },
    { role: 'content_manager', resource: 'content', action: 'delete:own', attributes: ['*'] }
  ],
  reviewer: [
    { role: 'reviewer', resource: 'users', action: 'read:any', attributes: ['name', 'email', 'role', 'organization'] },
    { role: 'reviewer', resource: 'content', action: 'read:any', attributes: ['*'] },
    { role: 'reviewer', resource: 'content', action: 'update:any', attributes: ['status', 'notes'] }
  ],
  healthcare_provider: [
    { role: 'healthcare_provider', resource: 'users', action: 'read:own', attributes: ['*', '!password', '!tokenKey'] },
    { role: 'healthcare_provider', resource: 'users', action: 'update:own', attributes: ['name', 'phone', 'organization', 'department', 'notes'] },
    { role: 'healthcare_provider', resource: 'content', action: 'read:any', attributes: ['*'] },
    { role: 'healthcare_provider', resource: 'content', action: 'create:own', attributes: ['title', 'body', 'category', 'tags'] }
  ],
  observer: [
    { role: 'observer', resource: 'users', action: 'read:any', attributes: ['name', 'role', 'organization'] },
    { role: 'observer', resource: 'content', action: 'read:any', attributes: ['*'] },
    { role: 'observer', resource: 'reports', action: 'read:any', attributes: ['*'] }
  ]
}

// Utility Types for Permission Management
export interface PermissionValidationResult {
  isValid: boolean
  errors: string[]
  warnings: string[]
}

export interface EffectivePermissions {
  [resource: string]: {
    [action: string]: {
      granted: boolean
      attributes: string[]
      inherited?: boolean
      source?: string // role that granted this permission
    }
  }
}

// Permission Context for React Components
export interface PermissionContextValue {
  permissions: EffectivePermissions
  hasPermission: (resource: string, action: PermissionAction, attributes?: string[]) => boolean
  checkPermission: (resource: string, action: PermissionAction) => PermissionCheck
  filterData: (resource: string, action: PermissionAction, data: any) => any
  loading: boolean
  error: Error | null
}
