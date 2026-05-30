"use client"

import * as React from "react"
import { PocketBaseDataTable } from "@/components/ui/pocketbase-datatable-simple"
import {
  BaseRecord,
  EnhancedPocketBaseDataTableProps,
} from "@/types/data-table"

export function EnhancedPocketBaseDataTable<TData extends BaseRecord = BaseRecord>(
  props: EnhancedPocketBaseDataTableProps<TData>
) {
  // Map legacy props to new simplified structure
  const {
    collectionName,
    collection = collectionName, // fallback to legacy prop
    columns,

    // Legacy PocketBase settings
    expand = "",
    filter = "",
    sort = "-created",
    fields,

    // Legacy pagination
    defaultPageSize = 20,

    // Legacy search
    searchable = true,
    searchFields = [],
    searchPlaceholder = "Search...",

    // Legacy selection
    selectable = true,

    // Actions (keep as-is)
    rowActions = [],
    bulkActions = [],

    // Legacy Export/Import
    exportable = false,
    importable = false,

    // Legacy UI
    title,
    description,

    // Legacy handlers
    onRowClick,
    onSelectionChange,
    onSelect = onSelectionChange, // new prop takes precedence
    onError,

    // Advanced filtering
    availableFields = []
  } = props
  // Use the new simplified DataTable component
  return (
    <PocketBaseDataTable<TData>
      collection={collection!}
      columns={columns}
      searchFields={searchable ? searchFields : []}
      searchPlaceholder={searchPlaceholder}
      rowActions={rowActions}
      bulkActions={selectable ? bulkActions : []}
      availableFields={availableFields}
      pocketbase={{
        expand,
        filter,
        sort,
        fields,
      }}
      ui={{
        pageSize: defaultPageSize,
        exportable,
        importable,
        title,
        description,
      }}
      onRowClick={onRowClick}
      onSelect={onSelect}
      onError={onError}
    />
  )
}