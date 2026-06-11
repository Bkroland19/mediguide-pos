"use client"

import { Badge } from "@/components/ui/badge"
import { DataTableColumnHeader } from "@/components/ui/datatable-column-header"
import { ExtendedColumnDef } from "@/types/data-table"
import { MedicalGuidelinesWithExpanded } from "@/types/expanded"

export const guidelinesColumns: ExtendedColumnDef<MedicalGuidelinesWithExpanded>[] = [
  {
    accessorKey: "icd10_code",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="ICD-10 Code" />
    ),
    cell: ({ row }) => {
      const icd10Code = row.getValue("icd10_code") as string
      return (
        <div className="font-mono text-sm">
          {icd10Code || (
            <span className="text-muted-foreground text-xs">Not specified</span>
          )}
        </div>
      )
    },
    enableSorting: true,
    enableHiding: true,
  },
  {
    accessorKey: "condition_name",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Condition Name" />
    ),
    cell: ({ row }) => (
      <div className="font-medium max-w-[300px]">
        <div className="truncate">{row.getValue("condition_name")}</div>
      </div>
    ),
    enableSorting: true,
    enableHiding: false,
  },
  {
    id: "index_item",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Index" />
    ),
    accessorFn: (row) => {
      const indexItem = row.expand?.index_item
      return indexItem?.title || "Not Assigned"
    },
    cell: ({ row }) => {
      const indexItem = row.original.expand?.index_item
      
      if (!indexItem) {
        return <span className="text-muted-foreground text-xs">Not Assigned</span>
      }
      
      return (
        <div className="max-w-[200px]">
          <div className="truncate text-sm font-medium">
            {indexItem.title}
          </div>
        </div>
      )
    },
    enableSorting: true,
    enableHiding: true,
  },
  {
    id: "categories",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Categories" />
    ),
    accessorFn: (row) => {
      const categories = row.expand?.categories
      return categories?.map(cat => cat.name).join(", ") || "No Categories"
    },
    cell: ({ row }) => {
      const categories = row.original.expand?.categories
      
      if (!categories || categories.length === 0) {
        return <span className="text-muted-foreground text-xs">No Categories</span>
      }
      
      return (
        <div className="flex flex-wrap gap-1">
          {categories.slice(0, 2).map((category) => (
            <Badge 
              key={category.id} 
              variant="secondary" 
              className="text-xs"
            >
              {category.name}
            </Badge>
          ))}
          {categories.length > 2 && (
            <Badge variant="outline" className="text-xs">
              +{categories.length - 2} more
            </Badge>
          )}
        </div>
      )
    },
    enableSorting: false,
    enableHiding: true,
    meta: {
      defaultVisible: false,
    },
  },
  {
    id: "tags",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Tags" />
    ),
    accessorFn: (row) => {
      const tags = row.expand?.tags
      return tags?.map(tag => tag.name).join(", ") || "No Tags"
    },
    cell: ({ row }) => {
      const tags = row.original.expand?.tags
      
      if (!tags || tags.length === 0) {
        return <span className="text-muted-foreground text-xs">No Tags</span>
      }
      
      return (
        <div className="flex flex-wrap gap-1">
          {tags.slice(0, 1).map((tag) => (
            <Badge 
              key={tag.id} 
              variant="outline" 
              className="text-xs"
            >
              {tag.name}
            </Badge>
          ))}
          {tags.length > 1 && (
            <Badge variant="secondary" className="text-xs">
              +{tags.length - 1} more
            </Badge>
          )}
        </div>
      )
    },
    enableSorting: false,
    enableHiding: true,
    meta: {
      defaultVisible: false,
    },
  },
  {
    accessorKey: "status",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Status" />
    ),
    cell: ({ row }) => {
      const status = row.getValue("status") as string
      
      const statusConfig = {
        draft: { variant: "secondary" as const, label: "Draft" },
        review: { variant: "outline" as const, label: "Under Review" },
        published: { variant: "default" as const, label: "Published" },
        archived: { variant: "destructive" as const, label: "Archived" },
      }
      
      const config = statusConfig[status as keyof typeof statusConfig] || {
        variant: "secondary" as const,
        label: status || "Unknown"
      }
      
      return (
        <Badge variant={config.variant} className="text-xs">
          {config.label}
        </Badge>
      )
    },
    enableSorting: true,
    enableHiding: true,
    meta: {
      defaultVisible: false,
    },
  },
  {
    accessorKey: "is_published",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Published" />
    ),
    cell: ({ row }) => {
      const isPublished = row.getValue("is_published") as boolean
      
      return (
        <Badge 
          variant={isPublished ? "default" : "secondary"} 
          className="text-xs"
        >
          {isPublished ? "Published" : "Unpublished"}
        </Badge>
      )
    },
    enableSorting: true,
    enableHiding: true,
    meta: {
      defaultVisible: false,
    },
  },
  {
    accessorKey: "priority",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Priority" />
    ),
    cell: ({ row }) => {
      const priority = row.getValue("priority") as string
      
      const priorityConfig = {
        high: { variant: "destructive" as const, label: "High" },
        medium: { variant: "outline" as const, label: "Medium" },
        low: { variant: "secondary" as const, label: "Low" },
      }
      
      const config = priorityConfig[priority as keyof typeof priorityConfig] || {
        variant: "secondary" as const,
        label: priority || "Not Set"
      }
      
      return (
        <Badge variant={config.variant} className="text-xs">
          {config.label}
        </Badge>
      )
    },
    enableSorting: true,
  },
  {
    accessorKey: "target_population",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Target Population" />
    ),
    cell: ({ row }) => {
      const target = row.getValue("target_population") as string
      return (
        <div className="text-xs text-muted-foreground max-w-[150px]">
          {target ? (
            <span className="truncate block">{target}</span>
          ) : (
            <span>Not specified</span>
          )}
        </div>
      )
    },
    enableSorting: true,
  },
  {
    accessorKey: "created",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Created" />
    ),
    cell: ({ row }) => {
      const date = new Date(row.getValue("created"))
      return (
        <div className="text-muted-foreground text-xs">
          {date.toLocaleDateString()}
        </div>
      )
    },
    enableSorting: true,
  },
]

export type MedicalGuidelineType = MedicalGuidelinesWithExpanded