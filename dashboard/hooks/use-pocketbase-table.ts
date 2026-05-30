"use client"

import { useState, useCallback, useEffect, useMemo, useRef } from 'react'
import { keepPreviousData, useQuery, useQueryClient } from "@tanstack/react-query"
import { getPB } from '@/lib/pocketbase'
import { showToast } from '@/lib/toast'
import {
  BaseRecord,
  UsePocketBaseTableConfig,
  UsePocketBaseTableReturn,
  LoadingStates,
  TableError,
  PaginationInfo,
  ExportFormat,
  ExpandConfig,
} from '@/types/data-table'

// Legacy config type for backward compatibility
export interface PocketBaseTableConfig<TData = BaseRecord> extends UsePocketBaseTableConfig<TData> {
  // Legacy props
  collectionName?: string
  expand?: string | any
  filter?: string
  sort?: string
  realtime?: boolean
  fields?: string
  defaultPageSize?: number
  pageSizeOptions?: number[]
  searchable?: boolean
  selectable?: boolean
  enableSelectAll?: boolean
  exportable?: boolean
  onSelectionChange?: (selectedRows: TData[]) => void
  importable?: boolean
  exportConfig?: any
  importConfig?: any
  title?: string
  description?: string
  toolbar?: boolean
  columnVisibility?: boolean
  onDataChange?: (data: TData[]) => void
}

export function usePocketBaseTable<TData extends BaseRecord = BaseRecord>(
  config: PocketBaseTableConfig<TData>
): UsePocketBaseTableReturn<TData> {
  // State management
  const [data, setData] = useState<TData[]>([])
  const [totalItems, setTotalItems] = useState(0)
  const [currentPage, setCurrentPage] = useState(1)
  const [currentPageSize, setCurrentPageSize] = useState(config.defaultPageSize || 20)
  const [selectedRows, setSelectedRows] = useState<TData[]>([])
  const [globalFilter, setGlobalFilter] = useState('')
  const [columnFilters, setColumnFilters] = useState<Record<string, unknown>>({})
  const [advancedFilters, setAdvancedFilters] = useState<import('@/types/data-table').AdvancedFilter[]>([])
  const [sorting, setSorting] = useState<{ id: string; desc: boolean }[]>([])
  const [expandedRows, setExpandedRows] = useState<Record<string, boolean>>({})
  const [error, setError] = useState<TableError | null>(null)
  
  const [actionLoading, setActionLoading] = useState({
    export: false,
    import: false,
    bulkAction: false,
  })

  const pb = useMemo(() => getPB(), [])
  const hasLoadedRef = useRef(false)
  const actionRef = useRef<'initial' | 'pagination' | 'table' | 'refresh'>('initial')
  const queryClient = useQueryClient()

  // Build expand query string from ExpandConfig
  const buildExpandQuery = useCallback((expandConfig: string | ExpandConfig | undefined): string => {
    if (!expandConfig) return ''
    
    if (typeof expandConfig === 'string') {
      return expandConfig
    }
    
    // Convert ExpandConfig to expand string
    const expandParts: string[] = []
    
    Object.entries(expandConfig.relations).forEach(([fieldName, relationConfig]) => {
      let expandPart = fieldName
      
      // Handle nested expansions
      if (relationConfig.nested) {
        const nestedExpand = buildExpandQuery(relationConfig.nested)
        if (nestedExpand) {
          expandPart += `.${nestedExpand}`
        }
      }
      
      expandParts.push(expandPart)
    })
    
    return expandParts.join(',')
  }, [])

  // Pagination info
  const paginationInfo: PaginationInfo = useMemo(() => ({
    page: currentPage,
    perPage: currentPageSize,
    totalItems,
    totalPages: Math.ceil(totalItems / currentPageSize),
    hasNextPage: currentPage < Math.ceil(totalItems / currentPageSize),
    hasPreviousPage: currentPage > 1
  }), [currentPage, currentPageSize, totalItems])

  // Convert advanced filter condition to PocketBase syntax
  const convertAdvancedFilterCondition = useCallback((filter: import('@/types/data-table').AdvancedFilter) => {
    const { field, condition, value } = filter
    
    switch (condition) {
      case 'equals':
        return `${field} = "${value}"`
      case 'not_equals':
        return `${field} != "${value}"`
      case 'contains':
        return `${field} ~ "${value}"`
      case 'starts_with':
        return `${field} ~ "^${value}"`
      case 'ends_with':
        return `${field} ~ "${value}$"`
      case 'greater_than':
        return `${field} > "${value}"`
      case 'less_than':
        return `${field} < "${value}"`
      case 'greater_equal':
        return `${field} >= "${value}"`
      case 'less_equal':
        return `${field} <= "${value}"`
      case 'is_empty':
        return `${field} = ""`
      case 'is_not_empty':
        return `${field} != ""`
      default:
        return `${field} = "${value}"`
    }
  }, [])

  // Build filter query
  const buildFilterQuery = useCallback(() => {
    const filters: string[] = []
    
    // Add base filter if provided
    if (config.filter) {
      filters.push(`(${config.filter})`)
    }

    // Add search filters
    if (globalFilter && config.searchFields?.length) {
      const searchConditions = config.searchFields.map(field => 
        `${field} ~ "${globalFilter}"`
      ).join(' || ')
      filters.push(`(${searchConditions})`)
    }

    // Add column filters with enhanced PocketBase syntax support
    Object.entries(columnFilters).forEach(([field, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        
        // Handle different filter value types with proper PocketBase syntax
        if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
          // Handle complex filter objects (e.g., date ranges, number ranges, relation fields)
          const filterObj = value as any
          
          if (filterObj.type === 'relation') {
            // Handle relation field filtering with explicit field path
            if (filterObj.relationField && filterObj.value) {
              filters.push(`${filterObj.relationField} ~ "${filterObj.value}"`)
            }
          } else if (filterObj.type === 'range') {
            // Number or date range filtering
            const conditions: string[] = []
            if (filterObj.min !== undefined && filterObj.min !== null && filterObj.min !== '') {
              conditions.push(`${field} >= "${filterObj.min}"`)
            }
            if (filterObj.max !== undefined && filterObj.max !== null && filterObj.max !== '') {
              conditions.push(`${field} <= "${filterObj.max}"`)
            }
            if (conditions.length > 0) {
              filters.push(`(${conditions.join(' && ')})`)
            }
          } else if (filterObj.type === 'dateRange') {
            // Date range with PocketBase datetime macros support
            const conditions: string[] = []
            
            // Handle preset date ranges with PocketBase macros
            if (filterObj.preset) {
              switch (filterObj.preset) {
                case 'today':
                  conditions.push(`${field} >= @todayStart`)
                  conditions.push(`${field} <= @todayEnd`)
                  break
                case 'thisWeek':
                  // This week (Sunday to Saturday) - custom logic needed
                  conditions.push(`${field} >= @todayStart - ((@weekday) * 86400)`) // Start of current week
                  conditions.push(`${field} <= @todayEnd + ((6 - @weekday) * 86400)`) // End of current week
                  break
                case 'thisMonth':
                  conditions.push(`${field} >= @monthStart`)
                  conditions.push(`${field} <= @monthEnd`)
                  break
                case 'thisYear':
                  conditions.push(`${field} >= @yearStart`)
                  conditions.push(`${field} <= @yearEnd`)
                  break
              }
            } else {
              // Use custom date range
              if (filterObj.start) {
                conditions.push(`${field} >= "${filterObj.start}"`)
              }
              if (filterObj.end) {
                conditions.push(`${field} <= "${filterObj.end}"`)
              }
            }
            
            if (conditions.length > 0) {
              filters.push(`(${conditions.join(' && ')})`)
            }
          } else if (filterObj.type === 'json') {
            // JSON field filtering
            if (filterObj.path && filterObj.value !== undefined) {
              const jsonPath = filterObj.path.split('.').join('.')
              filters.push(`json_extract(${field}, '$.${jsonPath}') = "${filterObj.value}"`)
            }
          }
        } else if (typeof value === 'string') {
          // Check if this is a JSON string containing relation field data
          try {
            const parsed = JSON.parse(value)
            if (parsed.type === 'relation' && parsed.relationField && parsed.value) {
              filters.push(`${parsed.relationField} ~ "${parsed.value}"`)
              return
            }
          } catch {
            // Not JSON, continue with string processing
          }
          
          // Enhanced string filtering - check for special syntax and relation fields
          if (value.startsWith('=')) {
            // Exact match
            const exactValue = value.substring(1)
            // For relation fields, don't use quotes
            if (field.endsWith('_id') || field.includes('.')) {
              filters.push(`${field} = "${exactValue}"`)
            } else {
              filters.push(`${field} = "${exactValue}"`)
            }
          } else if (value.startsWith('^')) {
            // Starts with
            filters.push(`${field} ~ "^${value.substring(1)}"`)
          } else if (value.endsWith('$')) {
            // Ends with (remove $ and add regex end)
            filters.push(`${field} ~ "${value.substring(0, value.length - 1)}$"`)
          } else {
            // Default contains - for relation fields, use direct field access
            if (field.includes('.')) {
              // This is a relation field access like "drug_class.name"
              filters.push(`${field} ~ "${value}"`)
            } else {
              // Regular field
              filters.push(`${field} ~ "${value}"`)
            }
          }
        } else if (typeof value === 'boolean') {
          filters.push(`${field} = ${value}`)
        } else if (typeof value === 'number') {
          filters.push(`${field} = ${value}`)
        } else if (Array.isArray(value)) {
          // Multi-select filters with OR condition
          if (value.length > 0) {
            const conditions = value.map(v => `${field} = "${v}"`).join(' || ')
            filters.push(`(${conditions})`)
          }
        }
      }
    })

    // Add advanced filters
    if (advancedFilters.length > 0) {
      const advancedConditions = advancedFilters.map(filter => 
        convertAdvancedFilterCondition(filter)
      )
      filters.push(...advancedConditions)
    }

    return filters.join(' && ')
  }, [config.filter, config.searchFields, globalFilter, columnFilters, advancedFilters, convertAdvancedFilterCondition])

  // Build sort query
  const buildSortQuery = useCallback(() => {
    if (sorting.length > 0) {
      return sorting.map(s => `${s.desc ? '-' : ''}${s.id}`).join(',')
    }
    return config.sort || '-created'
  }, [sorting, config.sort])

  const filterQuery = useMemo(() => buildFilterQuery(), [buildFilterQuery])
  const sortQuery = useMemo(() => buildSortQuery(), [buildSortQuery])
  const expandQuery = useMemo(() => buildExpandQuery(config.expand), [buildExpandQuery, config.expand])

  const queryKey = useMemo(() => [
    "pb",
    config.collectionName,
    {
      page: currentPage,
      perPage: currentPageSize,
      filter: filterQuery,
      sort: sortQuery,
      expand: expandQuery || "",
      fields: config.fields || "",
    }
  ], [config.collectionName, currentPage, currentPageSize, filterQuery, sortQuery, expandQuery, config.fields])

  const query = useQuery({
    queryKey,
    queryFn: async () => {
      return pb.collection(config.collectionName!).getList(currentPage, currentPageSize, {
        filter: filterQuery || undefined,
        sort: sortQuery,
        expand: expandQuery || undefined,
        fields: config.fields || undefined,
      })
    },
    placeholderData: keepPreviousData,
  })

  useEffect(() => {
    if (!query.data) return
    setData(query.data.items as unknown as TData[])
    setTotalItems(query.data.totalItems)
    setCurrentPage(query.data.page)
    hasLoadedRef.current = true
    setError(null)
    config.onDataChange?.(query.data.items as unknown as TData[])
  }, [query.data, config])

  useEffect(() => {
    if (!query.error) return
    const err = query.error as Error
    if (err.message?.includes("autocancelled")) return
    const error: TableError = {
      type: 'fetch',
      message: err.message || 'Failed to fetch data',
      details: err
    }
    setError(error)
    config.onError?.(err)
    showToast.error('Error', error.message)
  }, [query.error, config])

  // Refresh data
  const refresh = useCallback(async () => {
    actionRef.current = 'refresh'
    await queryClient.invalidateQueries({ queryKey: ["pb", config.collectionName] })
  }, [queryClient, config.collectionName])

  // Navigate to page
  const goToPage = useCallback(async (page: number) => {
    if (page >= 1 && page <= paginationInfo.totalPages) {
      actionRef.current = 'pagination'
      setCurrentPage(page)
    }
  }, [paginationInfo.totalPages])

  // Change page size
  const changePageSize = useCallback(async (size: number) => {
    actionRef.current = 'table'
    setCurrentPageSize(size)
    setCurrentPage(1)
    // fetchData will be called by useEffect when currentPageSize changes
  }, [])

  // Update filters
  const updateFilters = useCallback(async (filters: Record<string, unknown>) => {
    actionRef.current = 'table'
    setColumnFilters(filters)
    setCurrentPage(1)
    // fetchData will be called by useEffect when columnFilters changes
  }, [])

  // Update sorting
  const updateSorting = useCallback(async (newSorting: { id: string; desc: boolean }[]) => {
    actionRef.current = 'table'
    setSorting(newSorting)
    setCurrentPage(1)
    // fetchData will be called by useEffect when sorting changes
  }, [])

  // Update global filter
  const updateGlobalFilter = useCallback(async (filter: string) => {
    actionRef.current = 'table'
    setGlobalFilter(filter)
    setCurrentPage(1)
    // fetchData will be called by useEffect when globalFilter changes
  }, [])

  // Update advanced filters
  const updateAdvancedFilters = useCallback(async (filters: import('@/types/data-table').AdvancedFilter[]) => {
    actionRef.current = 'table'
    setAdvancedFilters(filters)
    setCurrentPage(1)
    // fetchData will be called by useEffect when advancedFilters changes
  }, [])

  // Selection management
  const selectRow = useCallback((row: TData) => {
    setSelectedRows(prev => {
      const isSelected = prev.some(r => r.id === row.id)
      if (isSelected) {
        return prev.filter(r => r.id !== row.id)
      } else {
        return [...prev, row]
      }
    })
  }, [])

  const selectAll = useCallback(() => {
    setSelectedRows(data)
    config.onSelectionChange?.(data)
  }, [data, config])

  const clearSelection = useCallback(() => {
    setSelectedRows([])
    config.onSelectionChange?.([])
  }, [config])

  // Expand management
  const toggleRowExpansion = useCallback((rowId: string) => {
    setExpandedRows(prev => ({
      ...prev,
      [rowId]: !prev[rowId]
    }))
  }, [])

  const expandAll = useCallback(() => {
    const allRowIds = data.reduce((acc, row) => {
      acc[row.id] = true
      return acc
    }, {} as Record<string, boolean>)
    setExpandedRows(allRowIds)
  }, [data])

  const collapseAll = useCallback(() => {
    setExpandedRows({})
  }, [])

  // Bulk operations
  const executeBulkAction = useCallback(async (actionId: string, rows: TData[]) => {
    const action = config.bulkActions?.find(a => a.id === actionId)
    if (!action) return

    setActionLoading(prev => ({ ...prev, bulkAction: true }))
    try {
      await action.onClick(rows)
      showToast.success('Success', `Bulk action "${action.label}" completed`)
      await refresh()
      clearSelection()
    } catch (err) {
      const error: TableError = {
        type: 'bulk_action',
        message: err instanceof Error ? err.message : 'Bulk action failed',
        details: err
      }
      setError(error)
      showToast.error('Error', error.message)
    } finally {
      setActionLoading(prev => ({ ...prev, bulkAction: false }))
    }
  }, [config.bulkActions, refresh, clearSelection])

  // Export functionality
  const exportData = useCallback(async (
    format: ExportFormat,
    options?: { selectedOnly?: boolean }
  ) => {
    const selectedOnly = options?.selectedOnly ?? false
    setActionLoading(prev => ({ ...prev, export: true }))
    try {
      const dataToExport = selectedOnly ? selectedRows : data
      const filename = config.exportConfig?.filename || `${config.collectionName}_export`

      if (format === 'csv') {
        await exportToCSV(dataToExport, `${filename}.csv`)
      } else if (format === 'json') {
        await exportToJSON(dataToExport, `${filename}.json`)
      } else if (format === 'xlsx') {
        await exportToExcel(dataToExport, `${filename}.xlsx`)
      }

      showToast.success('Success', `Data exported as ${format.toUpperCase()}`)
    } catch (err) {
      const error: TableError = {
        type: 'export',
        message: err instanceof Error ? err.message : 'Export failed',
        details: err
      }
      setError(error)
      showToast.error('Error', error.message)
    } finally {
      setActionLoading(prev => ({ ...prev, export: false }))
    }
  }, [selectedRows, data, config])

  // Import functionality
  const importData = useCallback(async (file: File, format: ExportFormat) => {
    setActionLoading(prev => ({ ...prev, import: true }))
    try {
      let importedData: unknown[]

      if (format === 'csv') {
        importedData = await parseCSV(file)
      } else if (format === 'json') {
        importedData = await parseJSON(file)
      } else {
        throw new Error(`Import format ${format} not supported`)
      }

      // Validate data if validator is provided
      if (config.importConfig?.validateData) {
        const { valid, errors } = await config.importConfig.validateData(importedData)
        if (errors.length > 0) {
          throw new Error(`Validation errors: ${errors.join(', ')}`)
        }
        importedData = valid
      }

      // Import data to PocketBase
      let successCount = 0
      for (const item of importedData) {
        try {
          await pb.collection(config.collectionName!).create(item as Record<string, any>)
          successCount++
        } catch (err) {
          console.warn('Failed to import item:', item, err)
        }
      }

      config.importConfig?.onSuccess?.(successCount)
      showToast.success('Success', `Imported ${successCount} records`)
      await refresh()
    } catch (err) {
      const error: TableError = {
        type: 'import',
        message: err instanceof Error ? err.message : 'Import failed',
        details: err
      }
      setError(error)
      config.importConfig?.onError?.([error.message])
      showToast.error('Error', error.message)
    } finally {
      setActionLoading(prev => ({ ...prev, import: false }))
    }
  }, [config, pb, refresh])

  // Realtime subscriptions
  useEffect(() => {
    if (!config.realtime) return

    const unsubscribe = pb.collection(config.collectionName!).subscribe('*', (e) => {
      if (e.action === 'create') {
        setData(prev => [e.record as unknown as TData, ...prev.slice(0, currentPageSize - 1)])
        setTotalItems(prev => prev + 1)
        showToast.info('New Record', `A new ${config.collectionName} record was created`)
      } else if (e.action === 'update') {
        setData(prev => prev.map(item => 
          item.id === e.record.id ? e.record as unknown as TData : item
        ))
        showToast.info('Record Updated', `A ${config.collectionName} record was updated`)
      } else if (e.action === 'delete') {
        setData(prev => prev.filter(item => item.id !== e.record.id))
        setTotalItems(prev => prev - 1)
        setSelectedRows(prev => prev.filter(item => item.id !== e.record.id))
        showToast.info('Record Deleted', `A ${config.collectionName} record was deleted`)
      }
    })

    return () => {
      pb.collection(config.collectionName!).unsubscribe('*')
    }
  }, [config.collectionName, config.realtime, currentPageSize, pb])

  // Effects for data fetching
  useEffect(() => {
    if (!hasLoadedRef.current) {
      actionRef.current = 'initial'
    }
    setCurrentPage(1)
  }, [currentPageSize, columnFilters, sorting, globalFilter, advancedFilters])


  // Selection change callback
  useEffect(() => {
    config.onSelectionChange?.(selectedRows)
  }, [selectedRows, config])

  const loading: LoadingStates = useMemo(() => ({
    initial: query.isPending && !hasLoadedRef.current,
    pagination: query.isFetching && actionRef.current === 'pagination',
    table: query.isFetching && actionRef.current === 'table',
    refresh: query.isFetching && actionRef.current === 'refresh',
    export: actionLoading.export,
    import: actionLoading.import,
    bulkAction: actionLoading.bulkAction,
  }), [actionLoading.bulkAction, actionLoading.export, actionLoading.import, query.isFetching, query.isPending])

  return {
    // Data
    data,
    totalItems,
    paginationInfo,

    // State
    loading,
    error,

    // Actions
    refresh,
    goToPage,
    changePageSize,
    updateFilters,
    updateSorting,
    updateGlobalFilter,
    updateAdvancedFilters,

    // Selection
    selectedRows,
    selectRow,
    selectAll,
    clearSelection,

    // Expand
    expandedRows,
    toggleRowExpansion,
    expandAll,
    collapseAll,

    // Bulk operations
    executeBulkAction,

    // Export/Import
    exportData,
    importData,
  }
}

// Helper functions for export/import
async function exportToCSV(data: unknown[], filename: string) {
  if (data.length === 0) return
  
  const headers = Object.keys(data[0] as Record<string, unknown>)
  const csvContent = [
    headers.join(','),
    ...data.map(row => headers.map(header => 
      JSON.stringify((row as Record<string, unknown>)[header] || '')
    ).join(','))
  ].join('\n')

  downloadFile(csvContent, filename, 'text/csv')
}

async function exportToJSON(data: unknown[], filename: string) {
  const jsonContent = JSON.stringify(data, null, 2)
  downloadFile(jsonContent, filename, 'application/json')
}

async function exportToExcel(data: unknown[], filename: string) {
  // This would require the 'xlsx' library to be installed
  // For now, we'll export as CSV as a fallback
  await exportToCSV(data, filename.replace('.xlsx', '.csv'))
}

async function parseCSV(file: File): Promise<unknown[]> {
  const text = await file.text()
  const lines = text.split('\n').filter(line => line.trim())
  
  if (lines.length < 2) return []
  
  const headers = lines[0].split(',').map(h => h.trim().replace(/"/g, ''))
  return lines.slice(1).map(line => {
    const values = line.split(',').map(v => v.trim().replace(/"/g, ''))
    return headers.reduce((obj, header, index) => {
      obj[header] = values[index] || ''
      return obj
    }, {} as Record<string, string>)
  })
}

async function parseJSON(file: File): Promise<unknown[]> {
  const text = await file.text()
  const data = JSON.parse(text)
  return Array.isArray(data) ? data : [data]
}

function downloadFile(content: string, filename: string, mimeType: string) {
  const blob = new Blob([content], { type: mimeType })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}
