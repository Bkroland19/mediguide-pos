"use client"

import * as React from "react"
import { Download, FileText, Database, FileSpreadsheet, Loader2 } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { BaseRecord, ExportFormat } from "@/types/data-table"
import { showToast } from "@/lib/toast"

interface DataTableExportProps<TData extends BaseRecord> {
  data?: TData[]
  selectedRows?: TData[]
  columns?: { id: string; label: string }[]
  formats?: ExportFormat[]
  filename?: string
  onExport?: (format: ExportFormat, options: ExportOptions) => Promise<void>
}

interface ExportOptions {
  format: ExportFormat
  filename: string
  selectedOnly: boolean
  includeHeaders: boolean
  selectedColumns: string[]
  dateRange?: { from: string; to: string }
}

const formatIcons = {
  csv: FileText,
  json: Database,
  xlsx: FileSpreadsheet,
}

const formatLabels = {
  csv: 'CSV',
  json: 'JSON',
  xlsx: 'Excel (XLSX)',
}

const formatDescriptions = {
  csv: 'Comma-separated values, compatible with spreadsheet applications',
  json: 'JavaScript Object Notation, ideal for data interchange',
  xlsx: 'Microsoft Excel format with advanced formatting support',
}

export function DataTableExport<TData extends BaseRecord>({
  data = [],
  selectedRows = [],
  columns = [],
  formats = ['csv', 'json', 'xlsx'],
  filename = 'export',
  onExport,
}: DataTableExportProps<TData>) {
  const [isOpen, setIsOpen] = React.useState(false)
  const [loading, setLoading] = React.useState(false)
  const [exportFormat, setExportFormat] = React.useState<ExportFormat>(formats[0])
  const [exportFilename, setExportFilename] = React.useState(filename)
  const [selectedOnly, setSelectedOnly] = React.useState(false)
  const [includeHeaders, setIncludeHeaders] = React.useState(true)
  const [selectedColumns, setSelectedColumns] = React.useState<string[]>(
    columns.map(col => col.id)
  )
  const [dateRange] = React.useState({ from: '', to: '' })

  const hasSelectedRows = selectedRows.length > 0
  const totalRows = selectedOnly ? selectedRows.length : data.length
  // const exportData = selectedOnly ? selectedRows : data

  React.useEffect(() => {
    setExportFilename(filename)
  }, [filename])

  React.useEffect(() => {
    setSelectedColumns(columns.map(col => col.id))
  }, [columns])

  const handleQuickExport = async (format: ExportFormat, selectedRowsOnly = false) => {
    if (!onExport) return

    setLoading(true)
    try {
      await onExport(format, {
        format,
        filename: `${filename}.${format}`,
        selectedOnly: selectedRowsOnly,
        includeHeaders: true,
        selectedColumns: columns.map(col => col.id),
      })
      showToast.success("Export Success", `Data exported as ${format.toUpperCase()}`)
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Export failed'
      showToast.error("Export Failed", message)
    } finally {
      setLoading(false)
    }
  }

  const handleAdvancedExport = async () => {
    if (!onExport) return

    setLoading(true)
    try {
      await onExport(exportFormat, {
        format: exportFormat,
        filename: exportFilename.endsWith(`.${exportFormat}`)
          ? exportFilename
          : `${exportFilename}.${exportFormat}`,
        selectedOnly,
        includeHeaders,
        selectedColumns,
        dateRange: dateRange.from && dateRange.to ? dateRange : undefined,
      })

      showToast.success("Export Success", `Data exported as ${exportFormat.toUpperCase()}`)
      setIsOpen(false)
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Export failed'
      showToast.error("Export Failed", message)
    } finally {
      setLoading(false)
    }
  }

  const toggleColumnSelection = (columnId: string) => {
    setSelectedColumns(prev =>
      prev.includes(columnId)
        ? prev.filter(id => id !== columnId)
        : [...prev, columnId]
    )
  }

  const selectAllColumns = () => {
    setSelectedColumns(columns.map(col => col.id))
  }

  const clearColumnSelection = () => {
    setSelectedColumns([])
  }

  if (formats.length === 0 || !onExport) {
    return null
  }

  // Simple dropdown for quick exports
  const renderQuickExport = () => (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="sm" disabled={loading}>
          {loading ? (
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
          ) : (
            <Download className="mr-2 h-4 w-4" />
          )}
          Export
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuLabel>Quick Export</DropdownMenuLabel>
        <DropdownMenuSeparator />

        {formats.map((format) => {
          const Icon = formatIcons[format]
          return (
            <DropdownMenuItem
              key={format}
              onClick={() => handleQuickExport(format, false)}
              disabled={loading}
            >
              <Icon className="mr-2 h-4 w-4" />
              Export all as {formatLabels[format]}
            </DropdownMenuItem>
          )
        })}

        {hasSelectedRows && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuLabel>Selected Only</DropdownMenuLabel>
            {formats.map((format) => {
              const Icon = formatIcons[format]
              return (
                <DropdownMenuItem
                  key={`selected-${format}`}
                  onClick={() => handleQuickExport(format, true)}
                  disabled={loading}
                >
                  <Icon className="mr-2 h-4 w-4" />
                  Export {selectedRows.length} as {formatLabels[format]}
                </DropdownMenuItem>
              )
            })}
          </>
        )}

        <DropdownMenuSeparator />
        <DropdownMenuItem
          onClick={() => setIsOpen(true)}
          disabled={loading}
        >
          <FileText className="mr-2 h-4 w-4" />
          Advanced Export...
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )

  return (
    <>
      {renderQuickExport()}

      <Dialog open={isOpen} onOpenChange={setIsOpen}>
        <DialogContent className="sm:max-w-[600px]">
          <DialogHeader>
            <DialogTitle>Export Data</DialogTitle>
            <DialogDescription>
              Configure your export settings and download your data.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-6">
            {/* Format Selection */}
            <div className="space-y-3">
              <Label className="text-sm font-medium">Export Format</Label>
              <RadioGroup
                value={exportFormat}
                onValueChange={(value) => setExportFormat(value as ExportFormat)}
                className="space-y-2"
              >
                {formats.map((format) => {
                  const Icon = formatIcons[format]
                  return (
                    <div key={format} className="flex items-center space-x-3 rounded-md border p-3">
                      <RadioGroupItem value={format} id={format} />
                      <Icon className="h-5 w-5 text-muted-foreground" />
                      <div className="flex-1">
                        <label htmlFor={format} className="text-sm font-medium cursor-pointer">
                          {formatLabels[format]}
                        </label>
                        <p className="text-xs text-muted-foreground">
                          {formatDescriptions[format]}
                        </p>
                      </div>
                    </div>
                  )
                })}
              </RadioGroup>
            </div>

            {/* Data Selection */}
            <div className="space-y-3">
              <Label className="text-sm font-medium">Data Selection</Label>
              <div className="space-y-2">
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="selected-only"
                    checked={selectedOnly}
                    onCheckedChange={(checked) => setSelectedOnly(checked === true)}
                    disabled={!hasSelectedRows}
                  />
                  <label htmlFor="selected-only" className="text-sm">
                    Export selected rows only
                    {hasSelectedRows && (
                      <Badge variant="secondary" className="ml-2">
                        {selectedRows.length} selected
                      </Badge>
                    )}
                  </label>
                </div>

                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="include-headers"
                    checked={includeHeaders}
                    onCheckedChange={(checked) => setIncludeHeaders(checked === true)}
                  />
                  <label htmlFor="include-headers" className="text-sm">
                    Include column headers
                  </label>
                </div>
              </div>
            </div>

            {/* Column Selection */}
            {columns.length > 0 && (
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label className="text-sm font-medium">Columns to Export</Label>
                  <div className="flex gap-2">
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={selectAllColumns}
                    >
                      Select All
                    </Button>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={clearColumnSelection}
                    >
                      Clear
                    </Button>
                  </div>
                </div>

                <div className="max-h-40 overflow-y-auto space-y-2 border rounded-md p-3">
                  {columns.map((column) => (
                    <div key={column.id} className="flex items-center space-x-2">
                      <Checkbox
                        id={`col-${column.id}`}
                        checked={selectedColumns.includes(column.id)}
                        onCheckedChange={() => toggleColumnSelection(column.id)}
                      />
                      <label
                        htmlFor={`col-${column.id}`}
                        className="text-sm cursor-pointer flex-1"
                      >
                        {column.label}
                      </label>
                    </div>
                  ))}
                </div>

                <p className="text-xs text-muted-foreground">
                  {selectedColumns.length} of {columns.length} columns selected
                </p>
              </div>
            )}

            {/* Filename */}
            <div className="space-y-3">
              <Label htmlFor="filename" className="text-sm font-medium">
                File Name
              </Label>
              <Input
                id="filename"
                value={exportFilename}
                onChange={(e) => setExportFilename(e.target.value)}
                placeholder="Enter filename"
              />
              <p className="text-xs text-muted-foreground">
                File will be saved as: {exportFilename || 'export'}.{exportFormat}
              </p>
            </div>

            {/* Summary */}
            <div className="rounded-md bg-muted p-3">
              <h4 className="text-sm font-medium mb-2">Export Summary</h4>
              <div className="text-xs text-muted-foreground space-y-1">
                <div>Format: {formatLabels[exportFormat]}</div>
                <div>Rows: {totalRows.toLocaleString()}</div>
                <div>Columns: {selectedColumns.length}</div>
                <div>Headers: {includeHeaders ? 'Included' : 'Excluded'}</div>
              </div>
            </div>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsOpen(false)}
              disabled={loading}
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleAdvancedExport}
              disabled={loading || selectedColumns.length === 0}
            >
              {loading ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Download className="mr-2 h-4 w-4" />
              )}
              Export Data
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}