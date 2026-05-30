"use client"

import { VisibilityState } from "@tanstack/react-table"

/**
 * Utility for persisting column visibility configurations in localStorage
 */

export interface ColumnConfig {
  visibility: VisibilityState
  lastUpdated: string
  version: string // For future migrations if needed
}

/**
 * Generate a unique key for the column configuration based on:
 * - Collection name
 * - User identifier (if available)
 * - Table context (page/component)
 */
export function getColumnConfigKey(
  collectionName: string, 
  userId?: string, 
  context?: string
): string {
  const parts = ['datatable-columns', collectionName]
  
  if (userId) {
    parts.push(userId)
  }
  
  if (context) {
    parts.push(context)
  }
  
  return parts.join('-')
}

/**
 * Save column visibility configuration to localStorage
 */
export function saveColumnConfig(
  key: string,
  visibility: VisibilityState
): void {
  try {
    const config: ColumnConfig = {
      visibility,
      lastUpdated: new Date().toISOString(),
      version: '1.0'
    }
    
    localStorage.setItem(key, JSON.stringify(config))
  } catch (error) {
    console.warn('Failed to save column configuration:', error)
  }
}

/**
 * Load column visibility configuration from localStorage
 */
export function loadColumnConfig(key: string): VisibilityState | null {
  try {
    const stored = localStorage.getItem(key)
    
    if (!stored) {
      return null
    }
    
    const config: ColumnConfig = JSON.parse(stored)
    
    // Validate the structure
    if (!config.visibility || typeof config.visibility !== 'object') {
      return null
    }
    
    return config.visibility
  } catch (error) {
    console.warn('Failed to load column configuration:', error)
    return null
  }
}

/**
 * Clear column configuration for a specific key
 */
export function clearColumnConfig(key: string): void {
  try {
    localStorage.removeItem(key)
  } catch (error) {
    console.warn('Failed to clear column configuration:', error)
  }
}

/**
 * Get all stored column configurations (for debugging/management)
 */
export function getAllColumnConfigs(): Record<string, ColumnConfig> {
  const configs: Record<string, ColumnConfig> = {}
  
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      
      if (key && key.startsWith('datatable-columns-')) {
        const stored = localStorage.getItem(key)
        if (stored) {
          try {
            configs[key] = JSON.parse(stored)
          } catch {
            // Skip invalid entries
          }
        }
      }
    }
  } catch (error) {
    console.warn('Failed to get all column configurations:', error)
  }
  
  return configs
}

/**
 * Clear all column configurations (useful for reset functionality)
 */
export function clearAllColumnConfigs(): void {
  try {
    const keysToRemove: string[] = []
    
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      if (key && key.startsWith('datatable-columns-')) {
        keysToRemove.push(key)
      }
    }
    
    keysToRemove.forEach(key => localStorage.removeItem(key))
  } catch (error) {
    console.warn('Failed to clear all column configurations:', error)
  }
}

/**
 * Merge default visibility with stored configuration
 * This ensures new columns are visible by default while preserving user preferences
 */
export function mergeColumnVisibility(
  defaultVisibility: VisibilityState,
  storedVisibility: VisibilityState | null
): VisibilityState {
  if (!storedVisibility) {
    return defaultVisibility
  }
  
  // Start with defaults to ensure new columns are visible
  const merged = { ...defaultVisibility }
  
  // Override with stored preferences for existing columns
  Object.keys(storedVisibility).forEach(columnId => {
    // Only apply stored preferences for columns that exist in defaults
    // This prevents issues if columns are removed/renamed
    if (columnId in defaultVisibility || storedVisibility[columnId] !== undefined) {
      merged[columnId] = storedVisibility[columnId]
    }
  })
  
  return merged
}

/**
 * Hook for managing column persistence in React components
 */
export function useColumnPersistence(
  collectionName: string,
  defaultVisibility: VisibilityState,
  userId?: string,
  context?: string
) {
  const key = getColumnConfigKey(collectionName, userId, context)
  
  // Load initial configuration
  const getInitialVisibility = (): VisibilityState => {
    const stored = loadColumnConfig(key)
    return mergeColumnVisibility(defaultVisibility, stored)
  }
  
  // Save configuration
  const saveVisibility = (visibility: VisibilityState) => {
    saveColumnConfig(key, visibility)
  }
  
  // Reset to defaults
  const resetToDefaults = () => {
    clearColumnConfig(key)
    return defaultVisibility
  }
  
  return {
    key,
    getInitialVisibility,
    saveVisibility,
    resetToDefaults,
  }
}