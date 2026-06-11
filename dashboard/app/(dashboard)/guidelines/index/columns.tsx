"use client"

import { Badge } from "@/components/ui/badge"
import { DataTableColumnHeader } from "@/components/ui/datatable-column-header"
import { ExtendedColumnDef } from "@/types/data-table"
import { GuidelineIndexWithExpanded } from "@/types/expanded"
import { ChevronRight, File, Folder } from "lucide-react"

export const guidelineIndexColumns: ExtendedColumnDef<GuidelineIndexWithExpanded>[] = [
  {
    id: "hierarchy",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Title" />
    ),
    accessorFn: (row) => row.title,
    cell: ({ row }) => {
      const level = row.original.level || 0
      const hasChildren = row.original.hasChildren || false
      const title = row.getValue("hierarchy") as string
      
      const indentWidth = level * 20 // 20px per level
      
      return (
        <div className="flex items-center" style={{ paddingLeft: `${indentWidth}px` }}>
          {hasChildren ? (
            <Folder className="mr-2 h-4 w-4 text-primary" />
          ) : (
            <File className="mr-2 h-4 w-4 text-muted-foreground" />
          )}
          <span className="font-medium truncate">{title}</span>
        </div>
      )
    },
    enableSorting: true,
    enableHiding: false,
    size: 400,
  },
  {
    accessorKey: "description",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Description" />
    ),
    cell: ({ row }) => {
      const description = row.getValue("description") as string
      return (
        <div className="text-sm text-muted-foreground max-w-[300px] truncate">
          {description || (
            <span className="italic">No description</span>
          )}
        </div>
      )
    },
    enableSorting: true,
    enableHiding: true,
  },
  {
    accessorKey: "level",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Level" />
    ),
    cell: ({ row }) => {
      const level = row.getValue("level") as number
      
      return (
        <Badge 
          variant="secondary" 
          className="text-xs font-mono"
        >
          L{level || 0}
        </Badge>
      )
    },
    enableSorting: true,
    enableHiding: true,
    size: 80,
  },
  {
    accessorKey: "order",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Order" />
    ),
    cell: ({ row }) => {
      const order = row.getValue("order") as number
      return (
        <div className="text-xs text-muted-foreground font-mono">
          {order || 0}
        </div>
      )
    },
    enableSorting: true,
    enableHiding: true,
    size: 80,
    meta: {
      defaultVisible: false,
    },
  },
  {
    accessorKey: "hasChildren",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Has Children" />
    ),
    cell: ({ row }) => {
      const hasChildren = row.getValue("hasChildren") as boolean
      
      return (
        <Badge 
          variant={hasChildren ? "default" : "secondary"} 
          className="text-xs"
        >
          {hasChildren ? "Folder" : "Item"}
        </Badge>
      )
    },
    enableSorting: true,
    enableHiding: true,
    size: 100,
    meta: {
      defaultVisible: false,
    },
  },
  {
    id: "parent",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Parent" />
    ),
    accessorFn: (row) => {
      const parent = row.expand?.parent?.[0]
      return parent?.title || "Root"
    },
    cell: ({ row }) => {
      const parent = row.original.expand?.parent?.[0]
      
      if (!parent) {
        return (
          <Badge variant="outline" className="text-xs">
            Root
          </Badge>
        )
      }
      
      return (
        <div className="flex items-center text-sm text-muted-foreground">
          <ChevronRight className="mr-1 h-3 w-3" />
          <span className="truncate max-w-[150px]">{parent.title}</span>
        </div>
      )
    },
    enableSorting: false,
    enableHiding: true,
    size: 150,
    meta: {
      defaultVisible: false,
    },
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
    enableHiding: true,
    size: 100,
    meta: {
      defaultVisible: false,
    },
  },
]

export type GuidelineIndexType = GuidelineIndexWithExpanded