"use client"

import * as React from "react"
import { X } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import {
  AdvancedFilter,
  FieldOption
} from "@/types/data-table"

interface ActiveFiltersPopupProps {
  filters: AdvancedFilter[]
  availableFields: FieldOption[]
  onRemoveFilter: (filterId: string) => void
  onClearAllFilters: () => void
  children: React.ReactNode
}

export function ActiveFiltersPopup({
  filters,
  availableFields,
  onRemoveFilter,
  onClearAllFilters,
  children,
}: ActiveFiltersPopupProps) {
  const [isOpen, setIsOpen] = React.useState(false)

  // Format condition text for better readability
  const formatCondition = (condition: string) => {
    return condition
      .replace(/_/g, ' ')
      .replace(/\b\w/g, (l) => l.toUpperCase())
  }

  // Get field label from available fields
  const getFieldLabel = (fieldValue: string) => {
    const field = availableFields.find(f => f.value === fieldValue)
    return field?.label || fieldValue
  }

  if (filters.length === 0) {
    return null
  }

  return (
    <Popover open={isOpen} onOpenChange={setIsOpen}>
      <PopoverTrigger asChild>
        {children}
      </PopoverTrigger>
      <PopoverContent align="start" className="w-80 p-0">
        <div className="p-4">
          <div className="flex items-center justify-between mb-3">
            <h4 className="font-medium text-sm">Active Filters</h4>
            <span className="text-xs text-muted-foreground">
              {filters.length} filter{filters.length !== 1 ? 's' : ''} applied
            </span>
          </div>

          <div className="space-y-2 mb-4">
            {filters.map((filter) => (
              <div
                key={filter.id}
                className="flex items-center justify-between p-2 bg-muted/30 rounded-md"
              >
                <div 
                  className="flex-1 min-w-0 cursor-pointer hover:opacity-70 transition-opacity"
                  onClick={() => onRemoveFilter(filter.id)}
                  title="Click to remove filter"
                >
                  <div className="flex items-center gap-1 text-xs">
                    <Badge variant="outline" className="text-xs px-1.5 py-0.5">
                      {getFieldLabel(filter.field)}
                    </Badge>
                    <span className="text-muted-foreground">
                      {formatCondition(filter.condition)}
                    </span>
                    {!['is_empty', 'is_not_empty'].includes(filter.condition) && (
                      <code className="text-xs bg-background px-1 py-0.5 rounded border">
                        {filter.displayValue ?? String(filter.value ?? '')}
                      </code>
                    )}
                  </div>
                </div>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => onRemoveFilter(filter.id)}
                  className="h-6 w-6 p-0 hover:bg-destructive hover:text-destructive-foreground"
                >
                  <X className="h-3 w-3" />
                </Button>
              </div>
            ))}
          </div>

          <Separator className="mb-4" />

          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              onClearAllFilters()
              setIsOpen(false)
            }}
            className="w-full"
          >
            Clear All Filters
          </Button>
        </div>
      </PopoverContent>
    </Popover>
  )
}