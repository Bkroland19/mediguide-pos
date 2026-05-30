"use client"

import * as React from "react"
import { Check, ChevronsUpDown, TreePine } from "lucide-react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import { Badge } from "@/components/ui/badge"
import { useGuidelineCategories, type CategoryTreeNode } from "@/hooks/use-guideline-categories"

interface GuidelineCategorySelectorProps {
  value?: string | string[]
  onValueChange?: (value: string | string[]) => void
  placeholder?: string
  allowEmpty?: boolean
  filterParent?: string
  excludeIds?: string[]
  multiple?: boolean
  showPath?: boolean
  disabled?: boolean
  className?: string
}

export function GuidelineCategorySelector({
  value,
  onValueChange,
  placeholder = "Select category...",
  allowEmpty = true,
  filterParent,
  excludeIds = [],
  multiple = false,
  showPath = false,
  disabled = false,
  className
}: GuidelineCategorySelectorProps) {
  const [open, setOpen] = React.useState(false)
  const [searchTerm, setSearchTerm] = React.useState("")

  const { 
    categories, 
    loading, 
    getCategoryById, 
    getCategoryPath,
    getCategoriesExcludingDescendants 
  } = useGuidelineCategories({
    includeInactive: false,
    parentId: filterParent,
    searchTerm
  })

  // Filter categories based on props
  const filteredCategories = React.useMemo(() => {
    let filtered = categories

    // Exclude specific IDs
    if (excludeIds.length > 0) {
      // If we're excluding categories, also exclude their descendants
      const allExcludeIds = new Set(excludeIds)
      excludeIds.forEach(id => {
        const category = getCategoryById(id)
        if (category) {
          const descendants = getCategoriesExcludingDescendants(id)
          const currentDescendants = categories.filter(cat => !descendants.some(desc => desc.id === cat.id))
          currentDescendants.forEach(desc => allExcludeIds.add(desc.id))
        }
      })
      filtered = filtered.filter(cat => !allExcludeIds.has(cat.id))
    }

    return filtered
  }, [categories, excludeIds, getCategoryById, getCategoriesExcludingDescendants])

  // Convert current value to array for easier handling
  const currentValues = React.useMemo(() => {
    if (!value) return []
    return Array.isArray(value) ? value : [value]
  }, [value])

  // Get selected categories
  const selectedCategories = React.useMemo(() => {
    return currentValues.map(id => getCategoryById(id)).filter(Boolean) as CategoryTreeNode[]
  }, [currentValues, getCategoryById])

  // Handle selection
  const handleSelect = (selectedId: string) => {
    if (multiple) {
      const newValues = currentValues.includes(selectedId)
        ? currentValues.filter(id => id !== selectedId)
        : [...currentValues, selectedId]
      onValueChange?.(newValues)
    } else {
      const newValue = currentValues.includes(selectedId) && allowEmpty ? "" : selectedId
      onValueChange?.(newValue)
      setOpen(false)
    }
  }

  // Format display text
  const getDisplayText = () => {
    if (selectedCategories.length === 0) {
      return placeholder
    }

    if (multiple) {
      return `${selectedCategories.length} selected`
    }

    const category = selectedCategories[0]
    if (showPath) {
      const path = getCategoryPath(category.id)
      return path.map(cat => cat.name).join(" / ")
    }

    return category.name
  }

  // Format category display in dropdown
  const formatCategoryDisplay = (category: CategoryTreeNode) => {
    const indent = "  ".repeat(category.level)
    let displayName = indent + category.name

    if (showPath && category.level > 0) {
      const path = getCategoryPath(category.id)
      const parentNames = path.slice(0, -1).map(cat => cat.name)
      if (parentNames.length > 0) {
        displayName = `${indent}${category.name} (${parentNames.join(" / ")})`
      }
    }

    return displayName
  }

  if (loading) {
    return (
      <Button
        variant="outline"
        role="combobox"
        disabled
        className={cn("w-full justify-between", className)}
      >
        Loading categories...
        <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
      </Button>
    )
  }

  return (
    <div className="space-y-2">
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            role="combobox"
            aria-expanded={open}
            disabled={disabled}
            className={cn("w-full justify-between", className)}
          >
            <span className="truncate text-left">
              {getDisplayText()}
            </span>
            <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-full p-0" align="start">
          <Command>
            <CommandInput 
              placeholder="Search categories..." 
              value={searchTerm}
              onValueChange={setSearchTerm}
            />
            <CommandList>
              <CommandEmpty>
                <div className="py-6 text-center text-sm">
                  <TreePine className="mx-auto h-8 w-8 text-muted-foreground mb-2" />
                  No categories found.
                </div>
              </CommandEmpty>
              <CommandGroup>
                {allowEmpty && !multiple && (
                  <CommandItem
                    value=""
                    onSelect={() => handleSelect("")}
                  >
                    <Check
                      className={cn(
                        "mr-2 h-4 w-4",
                        currentValues.length === 0 ? "opacity-100" : "opacity-0"
                      )}
                    />
                    <span className="italic text-muted-foreground">No category</span>
                  </CommandItem>
                )}
                {filteredCategories.map((category) => (
                  <CommandItem
                    key={category.id}
                    value={category.id}
                    onSelect={() => handleSelect(category.id)}
                    className={cn(
                      "flex items-start gap-2",
                      category.level > 0 && "pl-6"
                    )}
                  >
                    <Check
                      className={cn(
                        "mr-2 h-4 w-4 shrink-0 mt-0.5",
                        currentValues.includes(category.id) ? "opacity-100" : "opacity-0"
                      )}
                    />
                    <div className="flex-1 min-w-0">
                      <div className="font-medium truncate">
                        {formatCategoryDisplay(category)}
                      </div>
                      {category.description && (
                        <div className="text-xs text-muted-foreground truncate mt-1">
                          {category.description}
                        </div>
                      )}
                    </div>
                    {category.status === "inactive" && (
                      <Badge variant="secondary" className="text-xs">
                        Inactive
                      </Badge>
                    )}
                  </CommandItem>
                ))}
              </CommandGroup>
            </CommandList>
          </Command>
        </PopoverContent>
      </Popover>

      {/* Selected categories display for multiple selection */}
      {multiple && selectedCategories.length > 0 && (
        <div className="flex flex-wrap gap-1">
          {selectedCategories.map((category) => (
            <Badge 
              key={category.id} 
              variant="secondary" 
              className="text-xs"
            >
              {showPath ? getCategoryPath(category.id).map(cat => cat.name).join(" / ") : category.name}
              <button
                type="button"
                onClick={() => handleSelect(category.id)}
                className="ml-1 hover:bg-muted-foreground/20 rounded-full p-0.5"
              >
                ×
              </button>
            </Badge>
          ))}
        </div>
      )}
    </div>
  )
}

// Simple version for basic use cases
export function SimpleGuidelineCategorySelector({
  value,
  onValueChange,
  placeholder = "Select category...",
  className
}: {
  value?: string
  onValueChange?: (value: string) => void
  placeholder?: string
  className?: string
}) {
  return (
    <GuidelineCategorySelector
      value={value}
      onValueChange={onValueChange as (value: string | string[]) => void}
      placeholder={placeholder}
      multiple={false}
      showPath={false}
      className={className}
    />
  )
}

// Multi-select version
export function MultiGuidelineCategorySelector({
  value = [],
  onValueChange,
  placeholder = "Select categories...",
  className
}: {
  value?: string[]
  onValueChange?: (value: string[]) => void
  placeholder?: string
  className?: string
}) {
  return (
    <GuidelineCategorySelector
      value={value}
      onValueChange={onValueChange as (value: string | string[]) => void}
      placeholder={placeholder}
      multiple={true}
      showPath={true}
      className={className}
    />
  )
}