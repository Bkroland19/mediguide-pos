"use client"

import * as React from "react"
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
import { Check, ChevronDown, X } from "lucide-react"
import { cn } from "@/lib/utils"
import { 
  useGuidelineIndexSearch, 
  type UseGuidelineIndexSearchOptions,
  type GuidelineIndexItem 
} from "@/hooks/use-guideline-index-search"

export interface GuidelineIndexSelectorProps {
  /**
   * Current selected value (guideline index ID)
   */
  value?: string
  
  /**
   * Callback when selection changes
   */
  onValueChange: (value: string | undefined) => void
  
  /**
   * Placeholder text when no item is selected
   */
  placeholder?: string
  
  /**
   * Search input placeholder
   */
  searchPlaceholder?: string
  
  /**
   * Whether the selector is disabled
   */
  disabled?: boolean
  
  /**
   * Additional CSS classes for the trigger button
   */
  className?: string
  
  /**
   * Whether to show a "Root Level" option (value will be empty string)
   */
  showRootOption?: boolean
  
  /**
   * Label for the root option
   */
  rootOptionLabel?: string
  
  /**
   * Whether to allow clearing the selection
   */
  allowClear?: boolean
  
  /**
   * Options passed to the search hook
   */
  searchOptions?: UseGuidelineIndexSearchOptions
  
  /**
   * Custom render function for displaying selected item
   */
  renderSelectedItem?: (item: GuidelineIndexItem | null) => React.ReactNode
  
  /**
   * Custom render function for dropdown items
   */
  renderItem?: (item: GuidelineIndexItem) => React.ReactNode
  
  /**
   * Additional items to show in dropdown (e.g., from existing data)
   */
  additionalItems?: GuidelineIndexItem[]
}

/**
 * A reusable selector component for guideline index items with server-side search
 * 
 * @example
 * ```tsx
 * <GuidelineIndexSelector
 *   value={selectedParentId}
 *   onValueChange={setSelectedParentId}
 *   placeholder="Select parent item"
 *   showRootOption={true}
 *   searchOptions={{
 *     excludeIds: [currentItemId],
 *     maxLevel: currentLevel
 *   }}
 * />
 * ```
 */
export function GuidelineIndexSelector({
  value,
  onValueChange,
  placeholder = "Select guideline index item",
  searchPlaceholder = "Search items...",
  disabled = false,
  className,
  showRootOption = false,
  rootOptionLabel = "Root Level",
  allowClear = false,
  searchOptions,
  renderSelectedItem,
  renderItem,
  additionalItems = []
}: GuidelineIndexSelectorProps) {
  const [open, setOpen] = React.useState(false)
  
  const {
    searchTerm,
    setSearchTerm,
    results,
    isSearching,
    error
  } = useGuidelineIndexSearch(searchOptions)

  // Combine search results with additional items, removing duplicates
  const allItems = React.useMemo(() => {
    const combined = [...additionalItems, ...results]
    const seen = new Set<string>()
    return combined.filter(item => {
      if (seen.has(item.id)) {
        return false
      }
      seen.add(item.id)
      return true
    })
  }, [additionalItems, results])

  // Find selected item
  const selectedItem = React.useMemo(() => {
    if (!value) return null
    return allItems.find(item => item.id === value) || null
  }, [value, allItems])

  // Default render functions
  const defaultRenderSelectedItem = (item: GuidelineIndexItem | null) => {
    if (!item) return placeholder
    return item.title
  }

  const defaultRenderItem = (item: GuidelineIndexItem) => (
    <span className="truncate">{item.title}</span>
  )

  const handleSelect = (selectedValue: string) => {
    if (selectedValue === "root") {
      onValueChange("")
    } else {
      onValueChange(selectedValue)
    }
    setOpen(false)
  }

  const handleClear = (e: React.MouseEvent) => {
    e.stopPropagation()
    onValueChange(undefined)
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          className={cn("justify-between", className)}
          disabled={disabled}
        >
          <span className="truncate">
            {value === "" && showRootOption 
              ? rootOptionLabel 
              : (renderSelectedItem || defaultRenderSelectedItem)(selectedItem)
            }
          </span>
          <div className="flex items-center gap-1">
            {allowClear && value && !disabled && (
              <X 
                className="h-4 w-4 shrink-0 opacity-50 hover:opacity-100" 
                onClick={handleClear}
              />
            )}
            <ChevronDown className="h-4 w-4 shrink-0 opacity-50" />
          </div>
        </Button>
      </PopoverTrigger>
      
      <PopoverContent className="w-full p-0" align="start">
        <Command value={value || ""} shouldFilter={false}>
          <CommandInput
            placeholder={searchPlaceholder}
            value={searchTerm}
            onValueChange={setSearchTerm}
          />
          
          <CommandList>
            <CommandEmpty>
              {error ? (
                <div className="text-destructive text-sm p-2">
                  {error}
                </div>
              ) : isSearching ? (
                "Searching..."
              ) : searchTerm ? (
                "No items found."
              ) : (
                "Type to search for items"
              )}
            </CommandEmpty>
            
            <CommandGroup>
              {/* Root level option */}
              {showRootOption && (
                <CommandItem
                  value="root"
                  onSelect={(selectedValue) => handleSelect(selectedValue)}
                >
                  <Check
                    className={cn(
                      "mr-2 h-4 w-4",
                      value === "" ? "opacity-100" : "opacity-0"
                    )}
                  />
                  {rootOptionLabel}
                </CommandItem>
              )}
              
              {/* Search results and additional items */}
              {allItems.map((item) => (
                <CommandItem
                  key={item.id}
                  value={item.id}
                  onSelect={(selectedValue) => handleSelect(selectedValue)}
                >
                  <Check
                    className={cn(
                      "mr-2 h-4 w-4",
                      value === item.id ? "opacity-100" : "opacity-0"
                    )}
                  />
                  {(renderItem || defaultRenderItem)(item)}
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  )
}