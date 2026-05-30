"use client"

import * as React from "react"
import { 
  BaseRecord, 
  DataTableExpandableRowProps,
  RelationConfig
} from "@/types/data-table"

export function DataTableExpandableRow<TData extends BaseRecord = BaseRecord>({
  row,
  expandConfig,
  isExpanded,
  relationRenderers,
}: DataTableExpandableRowProps<TData>) {
  // Don't render if not expandable or no relations configured
  if (!expandConfig.relations || !isExpanded) {
    return null
  }

  const expandedData = row.expand
  if (!expandedData) return null

  return (
    <div className="p-4 bg-muted/30 border-t">
      <div className="space-y-3">
        {Object.entries(expandConfig.relations).map(([fieldName, relationConfig]) => (
          <RelationDisplay
            key={fieldName}
            fieldName={fieldName}
            relationConfig={relationConfig as RelationConfig}
            relationData={(expandedData as Record<string, unknown>)[fieldName]}
            parentRecord={row}
            relationRenderers={relationRenderers}
          />
        ))}
      </div>
    </div>
  )
}

interface RelationDisplayProps {
  fieldName: string
  relationConfig: RelationConfig
  relationData: unknown
  parentRecord: BaseRecord
  relationRenderers?: Record<string, React.ComponentType<{
    data: unknown
    config: RelationConfig
    parentRecord?: BaseRecord
    depth?: number
  }>>
}

function RelationDisplay({
  fieldName,
  relationConfig,
  relationData,
  parentRecord,
  relationRenderers,
}: RelationDisplayProps) {
  // Return null if no data
  if (!relationData) return null

  // Use custom renderer if provided
  const CustomRenderer = relationRenderers?.[fieldName]
  if (CustomRenderer) {
    return (
      <CustomRenderer
        data={relationData}
        config={relationConfig}
        parentRecord={parentRecord}
      />
    )
  }

  // Default renderer based on relation type
  switch (relationConfig.renderer) {
    case 'table':
      return (
        <RelationTable
          fieldName={fieldName}
          config={relationConfig}
          data={relationData}
        />
      )
    case 'list':
      return (
        <RelationList
          fieldName={fieldName}
          config={relationConfig}
          data={relationData}
        />
      )
    case 'inline':
      return (
        <RelationInline
          fieldName={fieldName}
          config={relationConfig}
          data={relationData}
        />
      )
    default:
      return (
        <RelationDefault
          fieldName={fieldName}
          config={relationConfig}
          data={relationData}
        />
      )
  }
}

// Default relation display - simple key-value pairs
function RelationDefault({
  fieldName,
  config,
  data,
}: {
  fieldName: string
  config: RelationConfig
  data: unknown
}) {
  return (
    <div className="space-y-2">
      <h4 className="text-sm font-medium text-muted-foreground">
        {config.collection} ({fieldName})
      </h4>
      <div className="pl-4">
        {Array.isArray(data) ? (
          <div className="space-y-1">
            {data.slice(0, config.maxRows || 5).map((item: BaseRecord, index: number) => (
              <div key={item.id || index} className="text-sm">
                {config.displayFields.map(field => 
                  item[field] ? (
                    <span key={field} className="mr-2">
                      <strong>{field}:</strong> {String(item[field])}
                    </span>
                  ) : null
                )}
              </div>
            ))}
            {data.length > (config.maxRows || 5) && (
              <div className="text-xs text-muted-foreground">
                ... and {data.length - (config.maxRows || 5)} more
              </div>
            )}
          </div>
        ) : (
          <div className="text-sm">
            {config.displayFields.map(field => {
              const value = (data as BaseRecord)?.[field]
              return value ? (
                <span key={field} className="mr-2">
                  <strong>{field}:</strong> {String(value)}
                </span>
              ) : null
            })}
          </div>
        )}
      </div>
    </div>
  )
}

// Inline relation display - compact single line
function RelationInline({
  fieldName,
  config,
  data,
}: {
  fieldName: string
  config: RelationConfig
  data: unknown
}) {
  if (Array.isArray(data)) {
    const displayItems = data.slice(0, config.maxRows || 3)
    const primaryField = config.displayFields[0]
    
    return (
      <div className="flex items-center space-x-2">
        <span className="text-sm font-medium text-muted-foreground">
          {fieldName}:
        </span>
        <div className="flex flex-wrap gap-1">
          {displayItems.map((item: BaseRecord, index: number) => (
            <span
              key={item.id || index}
              className="px-2 py-1 bg-secondary text-secondary-foreground rounded-md text-xs"
            >
              {String(item[primaryField] || item.id)}
            </span>
          ))}
          {data.length > displayItems.length && (
            <span className="text-xs text-muted-foreground">
              +{data.length - displayItems.length} more
            </span>
          )}
        </div>
      </div>
    )
  } else {
    const primaryField = config.displayFields[0]
    return (
      <div className="flex items-center space-x-2">
        <span className="text-sm font-medium text-muted-foreground">
          {fieldName}:
        </span>
        <span className="px-2 py-1 bg-secondary text-secondary-foreground rounded-md text-xs">
          {String((data as BaseRecord)?.[primaryField] || (data as BaseRecord)?.id || '')}
        </span>
      </div>
    )
  }
}

// List relation display - vertical list with bullets
function RelationList({
  fieldName,
  config,
  data,
}: {
  fieldName: string
  config: RelationConfig
  data: unknown
}) {
  return (
    <div className="space-y-2">
      <h4 className="text-sm font-medium text-muted-foreground">
        {config.collection} ({fieldName})
      </h4>
      <div className="pl-4">
        {Array.isArray(data) ? (
          <ul className="list-disc list-inside space-y-1">
            {data.slice(0, config.maxRows || 10).map((item: BaseRecord, index: number) => (
              <li key={item.id || index} className="text-sm">
                {config.displayFields.map((field, idx) => (
                  <span key={field}>
                    {String(item[field] || '')}
                    {idx < config.displayFields.length - 1 && ' • '}
                  </span>
                ))}
              </li>
            ))}
            {data.length > (config.maxRows || 10) && (
              <li className="text-xs text-muted-foreground">
                ... and {data.length - (config.maxRows || 10)} more items
              </li>
            )}
          </ul>
        ) : (
          <div className="text-sm">
            {config.displayFields.map((field, idx) => {
              const value = (data as BaseRecord)?.[field]
              return value ? (
                <span key={field}>
                  {String(value)}
                  {idx < config.displayFields.length - 1 && ' • '}
                </span>
              ) : null
            })}
          </div>
        )}
      </div>
    </div>
  )
}

// Table relation display - mini table for structured data
function RelationTable({
  fieldName,
  config,
  data,
}: {
  fieldName: string
  config: RelationConfig
  data: unknown
}) {
  if (!Array.isArray(data) || data.length === 0) {
    return <RelationDefault fieldName={fieldName} config={config} data={data} />
  }

  const displayData = data.slice(0, config.maxRows || 10)
  
  return (
    <div className="space-y-2">
      <h4 className="text-sm font-medium text-muted-foreground">
        {config.collection} ({fieldName})
      </h4>
      <div className="overflow-hidden rounded border">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-muted/50">
              <tr>
                {config.displayFields.map(field => (
                  <th key={field} className="px-2 py-1 text-left font-medium">
                    {field}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {displayData.map((item: BaseRecord, index: number) => (
                <tr key={item.id || index} className="border-t">
                  {config.displayFields.map(field => (
                    <td key={field} className="px-2 py-1">
                      {String(item[field] || '')}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {data.length > displayData.length && (
          <div className="px-2 py-1 bg-muted/30 text-xs text-muted-foreground border-t">
            ... and {data.length - displayData.length} more rows
          </div>
        )}
      </div>
    </div>
  )
}