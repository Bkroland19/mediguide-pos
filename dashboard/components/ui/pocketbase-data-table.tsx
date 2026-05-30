"use client"

import * as React from "react"
import {
  ColumnDef,
  ColumnFiltersState,
  SortingState,
  VisibilityState,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  useReactTable,
} from "@tanstack/react-table"
import { ChevronDown, Search, RefreshCw, Loader2 } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { getPB } from "@/lib/pocketbase"
import { showToast } from "@/lib/toast"

interface PocketBaseDataTableProps<TData = Record<string, unknown>> {
  collectionName: string
  columns: ColumnDef<TData, unknown>[]
  searchKey?: string
  searchPlaceholder?: string
  filter?: string
  expand?: string
  sort?: string
  perPage?: number
  realtime?: boolean
  onRowClick?: (row: TData) => void
  onError?: (error: Error) => void
}

export function PocketBaseDataTable<TData = Record<string, unknown>>({
  collectionName,
  columns,
  searchKey,
  searchPlaceholder = "Search...",
  filter = "",
  expand = "",
  sort = "-created",
  perPage = 20,
  realtime = false,
  onRowClick,
  onError,
}: PocketBaseDataTableProps<TData>) {
  const [data, setData] = React.useState<TData[]>([])
  const [loading, setLoading] = React.useState(true)
  const [error, setError] = React.useState<string | null>(null)
  const [totalItems, setTotalItems] = React.useState(0)
  const [currentPage, setCurrentPage] = React.useState(1)
  const [refreshing, setRefreshing] = React.useState(false)

  const [sorting, setSorting] = React.useState<SortingState>([])
  const [columnFilters, setColumnFilters] = React.useState<ColumnFiltersState>([])
  const defaultColumnVisibility = React.useMemo<VisibilityState>(() => {
    const hidden = new Set([
      "status",
      "created",
      "updated",
      "order",
    ])
    const visibility: VisibilityState = {}

    const getColumnId = (column: ColumnDef<TData, unknown>) => {
      if (column.id) return column.id
      if ("accessorKey" in column && typeof column.accessorKey === "string") {
        return column.accessorKey
      }
      return undefined
    }

    columns.forEach((column) => {
      const id = getColumnId(column)
      if (id && hidden.has(id)) {
        visibility[id] = false
      }
    })

    return visibility
  }, [columns])

  const [columnVisibility, setColumnVisibility] = React.useState<VisibilityState>(
    defaultColumnVisibility
  )
  const [rowSelection, setRowSelection] = React.useState({})

  const pb = React.useMemo(() => getPB(), [])

  React.useEffect(() => {
    setColumnVisibility((prev) => ({ ...defaultColumnVisibility, ...prev }))
  }, [defaultColumnVisibility])

  const fetchData = React.useCallback(async (page = 1, showLoader = true) => {
    try {
      if (showLoader) setLoading(true)
      setError(null)

      // Build filter query
      let filterQuery = filter
      if (searchKey && columnFilters.length > 0) {
        const searchFilter = columnFilters.find(f => f.id === searchKey)
        if (searchFilter && searchFilter.value) {
          const searchValue = searchFilter.value as string
          const searchCondition = `${searchKey} ~ "${searchValue}"`
          filterQuery = filterQuery 
            ? `(${filterQuery}) && ${searchCondition}`
            : searchCondition
        }
      }

      // Build sort query from table state
      let sortQuery = sort
      if (sorting.length > 0) {
        sortQuery = sorting
          .map(s => `${s.desc ? '-' : ''}${s.id}`)
          .join(',')
      }

      const result = await pb.collection(collectionName).getList(page, perPage, {
        filter: filterQuery,
        sort: sortQuery,
        expand,
      })

      setData(result.items as TData[])
      setTotalItems(result.totalItems)
      setCurrentPage(page)
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch data'
      setError(errorMessage)
      onError?.(err instanceof Error ? err : new Error('Unknown error'))
      showToast.error("Error", errorMessage)
      console.error('PocketBase DataTable error:', err)
    } finally {
      setLoading(false)
      setRefreshing(false)
    }
  }, [collectionName, filter, expand, sort, perPage, searchKey, columnFilters, sorting, onError, pb])

  const handleRefresh = React.useCallback(async () => {
    setRefreshing(true)
    await fetchData(currentPage, false)
  }, [fetchData, currentPage])

  // Initial data fetch
  React.useEffect(() => {
    fetchData(1)
  }, [fetchData])

  // Realtime subscriptions
  React.useEffect(() => {
    if (!realtime) return

    pb.collection(collectionName).subscribe('*', (e) => {
      if (e.action === 'create') {
        setData(prev => [e.record as TData, ...prev.slice(0, perPage - 1)])
        showToast.info("New Record", `A new ${collectionName} record was created`)
      } else if (e.action === 'update') {
        setData(prev => prev.map(item => 
          (item as Record<string, unknown>).id === e.record.id ? e.record as TData : item
        ))
        showToast.info("Record Updated", `A ${collectionName} record was updated`)
      } else if (e.action === 'delete') {
        setData(prev => prev.filter(item => (item as Record<string, unknown>).id !== e.record.id))
        showToast.info("Record Deleted", `A ${collectionName} record was deleted`)
      }
    })

    return () => {
      pb.collection(collectionName).unsubscribe('*')
    }
  }, [collectionName, realtime, perPage, pb])

  const table = useReactTable({
    data,
    columns,
    pageCount: Math.ceil(totalItems / perPage),
    state: {
      sorting,
      columnFilters,
      columnVisibility,
      rowSelection,
      pagination: {
        pageIndex: currentPage - 1,
        pageSize: perPage,
      },
    },
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    onColumnVisibilityChange: setColumnVisibility,
    onRowSelectionChange: setRowSelection,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    manualPagination: true,
    manualSorting: true,
    manualFiltering: true,
  })

  const handlePreviousPage = () => {
    if (currentPage > 1) {
      fetchData(currentPage - 1)
    }
  }

  const handleNextPage = () => {
    if (currentPage < Math.ceil(totalItems / perPage)) {
      fetchData(currentPage + 1)
    }
  }

  if (error) {
    return (
      <Alert variant="destructive">
        <AlertDescription className="flex items-center justify-between">
          <span>{error}</span>
          <Button variant="outline" size="sm" onClick={handleRefresh}>
            <RefreshCw className="h-4 w-4 mr-2" />
            Retry
          </Button>
        </AlertDescription>
      </Alert>
    )
  }

  return (
    <div className="w-full">
      <div className="flex items-center py-4">
        {searchKey && (
          <div className="relative flex-1 max-w-sm">
            <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder={searchPlaceholder}
              value={(table.getColumn(searchKey)?.getFilterValue() as string) ?? ""}
              onChange={(event) => {
                table.getColumn(searchKey)?.setFilterValue(event.target.value)
                // Debounce search
                const timeoutId = setTimeout(() => {
                  fetchData(1)
                }, 300)
                return () => clearTimeout(timeoutId)
              }}
              className="pl-8"
            />
          </div>
        )}
        
        <div className="ml-auto flex items-center gap-2">
          <Button 
            variant="outline" 
            size="sm" 
            onClick={handleRefresh}
            disabled={loading || refreshing}
          >
            {refreshing ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <RefreshCw className="h-4 w-4" />
            )}
          </Button>
          
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline">
                Columns <ChevronDown className="ml-2 h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {table
                .getAllColumns()
                .filter((column) => column.getCanHide())
                .map((column) => {
                  return (
                    <DropdownMenuCheckboxItem
                      key={column.id}
                      className="capitalize"
                      checked={column.getIsVisible()}
                      onCheckedChange={(value) =>
                        column.toggleVisibility(!!value)
                      }
                    >
                      {column.id}
                    </DropdownMenuCheckboxItem>
                  )
                })}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map((header) => {
                  return (
                    <TableHead key={header.id}>
                      {header.isPlaceholder
                        ? null
                        : flexRender(
                            header.column.columnDef.header,
                            header.getContext()
                          )}
                    </TableHead>
                  )
                })}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={columns.length} className="h-24 text-center">
                  <div className="flex items-center justify-center">
                    <Loader2 className="h-6 w-6 animate-spin mr-2" />
                    Loading {collectionName}...
                  </div>
                </TableCell>
              </TableRow>
            ) : table.getRowModel().rows?.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow
                  key={row.id}
                  data-state={row.getIsSelected() && "selected"}
                  className={onRowClick ? "cursor-pointer hover:bg-muted/50" : ""}
                  onClick={() => onRowClick?.(row.original)}
                >
                  {row.getVisibleCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {flexRender(
                        cell.column.columnDef.cell,
                        cell.getContext()
                      )}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell
                  colSpan={columns.length}
                  className="h-24 text-center"
                >
                  No {collectionName} found.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <div className="flex items-center justify-between space-x-2 py-4">
        <div className="flex-1 text-sm text-muted-foreground">
          {table.getFilteredSelectedRowModel().rows.length} of{" "}
          {totalItems} row(s) selected. 
          {totalItems > 0 && (
            <span className="ml-2">
              Page {currentPage} of {Math.ceil(totalItems / perPage)}
            </span>
          )}
        </div>
        <div className="space-x-2">
          <Button
            variant="outline"
            size="sm"
            onClick={handlePreviousPage}
            disabled={currentPage <= 1 || loading}
          >
            Previous
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={handleNextPage}
            disabled={currentPage >= Math.ceil(totalItems / perPage) || loading}
          >
            Next
          </Button>
        </div>
      </div>
    </div>
  )
}
