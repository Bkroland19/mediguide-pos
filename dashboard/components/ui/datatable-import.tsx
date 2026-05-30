"use client"

import * as React from "react"
import {
  Upload,
  Loader2,
  CheckCircle,
  AlertCircle,
  X,
  Download
} from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Progress } from "@/components/ui/progress"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Checkbox } from "@/components/ui/checkbox"
import { Separator } from "@/components/ui/separator"
import { ScrollArea } from "@/components/ui/scroll-area"
import { ExportFormat } from "@/types/data-table"
import { showToast } from "@/lib/toast"

interface DataTableImportProps {
  formats?: ExportFormat[]
  onImport?: (file: File, format: ExportFormat, options: ImportOptions) => Promise<ImportResult>
  maxFileSize?: number // in MB
  sampleData?: Record<string, unknown>
  requiredFields?: string[]
  onDownloadTemplate?: (format: ExportFormat) => void
}

interface ImportOptions {
  validateData: boolean
  skipErrors: boolean
  updateExisting: boolean
  batchSize: number
}

interface ImportResult {
  success: boolean
  imported: number
  errors: string[]
  warnings: string[]
  skipped?: number
  updated?: number
}

interface PreviewData {
  headers: string[]
  rows: Record<string, unknown>[]
  totalRows: number
}



export function DataTableImport({
  formats = ['csv', 'json'],
  onImport,
  maxFileSize = 10, // 10MB default
  requiredFields = [],
  onDownloadTemplate,
}: DataTableImportProps) {
  const [isOpen, setIsOpen] = React.useState(false)
  const [selectedFile, setSelectedFile] = React.useState<File | null>(null)
  const [previewData, setPreviewData] = React.useState<PreviewData | null>(null)
  const [importFormat, setImportFormat] = React.useState<ExportFormat>(formats[0])
  const [loading, setLoading] = React.useState(false)
  const [importing, setImporting] = React.useState(false)
  const [progress, setProgress] = React.useState(0)
  const [result, setResult] = React.useState<ImportResult | null>(null)
  const [errors, setErrors] = React.useState<string[]>([])

  // Import options
  const [validateData, setValidateData] = React.useState(true)
  const [skipErrors, setSkipErrors] = React.useState(true)
  const [updateExisting, setUpdateExisting] = React.useState(false)
  const [batchSize, setBatchSize] = React.useState(100)

  const fileInputRef = React.useRef<HTMLInputElement>(null)

  const handleFileSelect = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    // Validate file size
    if (file.size > maxFileSize * 1024 * 1024) {
      showToast.error("File Too Large", `File size must be less than ${maxFileSize}MB`)
      return
    }

    // Validate file type
    const fileExtension = file.name.split('.').pop()?.toLowerCase()
    if (!fileExtension || !formats.some(format =>
      (format === 'csv' && fileExtension === 'csv') ||
      (format === 'json' && fileExtension === 'json') ||
      (format === 'xlsx' && (fileExtension === 'xlsx' || fileExtension === 'xls'))
    )) {
      showToast.error("Invalid File Type", `Please select a ${formats.map(f => f.toUpperCase()).join(', ')} file`)
      return
    }

    setSelectedFile(file)
    setImportFormat(fileExtension as ExportFormat)
    setErrors([])

    await previewFile(file, fileExtension as ExportFormat)
  }

  const previewFile = async (file: File, format: ExportFormat) => {
    setLoading(true)
    try {
      let data: PreviewData

      if (format === 'csv') {
        data = await parseCSVPreview(file)
      } else if (format === 'json') {
        data = await parseJSONPreview(file)
      } else {
        throw new Error(`Preview for ${format} format is not supported yet`)
      }

      setPreviewData(data)

      // Validate headers against required fields
      const missingFields = requiredFields.filter(field =>
        !data.headers.some(header =>
          header.toLowerCase() === field.toLowerCase()
        )
      )

      if (missingFields.length > 0) {
        setErrors([`Missing required fields: ${missingFields.join(', ')}`])
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to preview file'
      setErrors([message])
      showToast.error("Preview Failed", message)
    } finally {
      setLoading(false)
    }
  }

  const handleImport = async () => {
    if (!selectedFile || !onImport || errors.length > 0) return

    setImporting(true)
    setProgress(0)

    try {
      const options: ImportOptions = {
        validateData,
        skipErrors,
        updateExisting,
        batchSize,
      }

      // Simulate progress for better UX
      const progressInterval = setInterval(() => {
        setProgress(prev => Math.min(prev + 10, 90))
      }, 500)

      const result = await onImport(selectedFile, importFormat, options)

      clearInterval(progressInterval)
      setProgress(100)
      setResult(result)

      if (result.success) {
        showToast.success(
          "Import Successful",
          `Imported ${result.imported} records successfully`
        )
      } else {
        showToast.error(
          "Import Failed",
          `Import failed with ${result.errors.length} errors`
        )
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Import failed'
      showToast.error("Import Failed", message)
      setResult({
        success: false,
        imported: 0,
        errors: [message],
        warnings: [],
      })
    } finally {
      setImporting(false)
    }
  }

  const resetImport = () => {
    setSelectedFile(null)
    setPreviewData(null)
    setResult(null)
    setErrors([])
    setProgress(0)
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  const renderFileInput = () => (
    <div className="space-y-4">
      <div className="flex items-center justify-center border-2 border-dashed border-muted-foreground/25 rounded-lg p-8">
        <div className="text-center space-y-4">
          <Upload className="h-10 w-10 mx-auto text-muted-foreground" />
          <div>
            <Button
              type="button"
              variant="outline"
              onClick={() => fileInputRef.current?.click()}
              disabled={loading}
            >
              {loading ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Upload className="mr-2 h-4 w-4" />
              )}
              Choose File
            </Button>
            <Input
              ref={fileInputRef}
              type="file"
              accept={formats.map(f => `.${f}`).join(',')}
              onChange={handleFileSelect}
              className="hidden"
            />
          </div>
          <div className="text-sm text-muted-foreground space-y-1">
            <p>Upload a {formats.map(f => f.toUpperCase()).join(', ')} file</p>
            <p>Maximum file size: {maxFileSize}MB</p>
          </div>
        </div>
      </div>

      {onDownloadTemplate && (
        <div className="flex items-center justify-center">
          <Button
            type="button"
            variant="link"
            size="sm"
            onClick={() => onDownloadTemplate(formats[0])}
          >
            <Download className="mr-2 h-4 w-4" />
            Download Template
          </Button>
        </div>
      )}
    </div>
  )

  const renderPreview = () => {
    if (!previewData) return null

    return (
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h4 className="font-medium">Preview</h4>
            <p className="text-sm text-muted-foreground">
              {previewData.totalRows} rows found
            </p>
          </div>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={resetImport}
          >
            <X className="mr-2 h-4 w-4" />
            Change File
          </Button>
        </div>

        {errors.length > 0 && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              <ul className="list-disc list-inside space-y-1">
                {errors.map((error, index) => (
                  <li key={index}>{error}</li>
                ))}
              </ul>
            </AlertDescription>
          </Alert>
        )}

        <ScrollArea className="h-[200px] border rounded-md">
          <div className="p-4">
            <div className="grid gap-2" style={{
              gridTemplateColumns: `repeat(${previewData.headers.length}, minmax(100px, 1fr))`
            }}>
              {/* Headers */}
              {previewData.headers.map((header, index) => (
                <div key={index} className="font-medium text-sm border-b pb-2">
                  {header}
                  {requiredFields.includes(header) && (
                    <Badge variant="secondary" className="ml-1 text-xs">
                      Required
                    </Badge>
                  )}
                </div>
              ))}

              {/* Sample rows */}
              {previewData.rows.slice(0, 5).map((row, rowIndex) => (
                previewData.headers.map((header, colIndex) => (
                  <div key={`${rowIndex}-${colIndex}`} className="text-sm py-1">
                    {String(row[header] || '').slice(0, 50)}
                    {String(row[header] || '').length > 50 && '...'}
                  </div>
                ))
              ))}
            </div>
          </div>
        </ScrollArea>

        {/* Import Options */}
        <div className="space-y-4">
          <Separator />
          <h4 className="font-medium">Import Options</h4>

          <div className="grid grid-cols-2 gap-4">
            <div className="flex items-center space-x-2">
              <Checkbox
                id="validate-data"
                checked={validateData}
                onCheckedChange={(checked) => setValidateData(checked === true)}
              />
              <label htmlFor="validate-data" className="text-sm">
                Validate data
              </label>
            </div>

            <div className="flex items-center space-x-2">
              <Checkbox
                id="skip-errors"
                checked={skipErrors}
                onCheckedChange={(checked) => setSkipErrors(checked === true)}
              />
              <label htmlFor="skip-errors" className="text-sm">
                Skip rows with errors
              </label>
            </div>

            <div className="flex items-center space-x-2">
              <Checkbox
                id="update-existing"
                checked={updateExisting}
                onCheckedChange={(checked) => setUpdateExisting(checked === true)}
              />
              <label htmlFor="update-existing" className="text-sm">
                Update existing records
              </label>
            </div>

            <div className="space-y-2">
              <Label htmlFor="batch-size" className="text-sm">
                Batch size
              </Label>
              <Input
                id="batch-size"
                type="number"
                min={10}
                max={1000}
                value={batchSize}
                onChange={(e) => setBatchSize(Number(e.target.value))}
                className="h-8"
              />
            </div>
          </div>
        </div>
      </div>
    )
  }

  const renderProgress = () => (
    <div className="space-y-4">
      <div className="text-center">
        <Loader2 className="h-8 w-8 animate-spin mx-auto mb-2" />
        <h4 className="font-medium">Importing Data...</h4>
        <p className="text-sm text-muted-foreground">
          Please wait while we process your file
        </p>
      </div>

      <Progress value={progress} className="w-full" />

      <p className="text-sm text-center text-muted-foreground">
        {progress}% complete
      </p>
    </div>
  )

  const renderResult = () => {
    if (!result) return null

    return (
      <div className="space-y-4">
        <div className="text-center">
          {result.success ? (
            <CheckCircle className="h-8 w-8 text-green-500 mx-auto mb-2" />
          ) : (
            <AlertCircle className="h-8 w-8 text-destructive mx-auto mb-2" />
          )}
          <h4 className="font-medium">
            {result.success ? 'Import Completed' : 'Import Failed'}
          </h4>
        </div>

        <div className="grid grid-cols-2 gap-4 text-center">
          <div className="space-y-1">
            <div className="text-2xl font-bold text-green-600">
              {result.imported}
            </div>
            <div className="text-sm text-muted-foreground">Imported</div>
          </div>

          {result.errors.length > 0 && (
            <div className="space-y-1">
              <div className="text-2xl font-bold text-red-600">
                {result.errors.length}
              </div>
              <div className="text-sm text-muted-foreground">Errors</div>
            </div>
          )}
        </div>

        {result.errors.length > 0 && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              <ScrollArea className="h-[100px]">
                <ul className="list-disc list-inside space-y-1">
                  {result.errors.map((error, index) => (
                    <li key={index} className="text-sm">{error}</li>
                  ))}
                </ul>
              </ScrollArea>
            </AlertDescription>
          </Alert>
        )}

        {result.warnings.length > 0 && (
          <Alert>
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              <ScrollArea className="h-[100px]">
                <ul className="list-disc list-inside space-y-1">
                  {result.warnings.map((warning, index) => (
                    <li key={index} className="text-sm">{warning}</li>
                  ))}
                </ul>
              </ScrollArea>
            </AlertDescription>
          </Alert>
        )}
      </div>
    )
  }

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">
          <Upload className="mr-2 h-4 w-4" />
          Import
        </Button>
      </DialogTrigger>

      <DialogContent className="sm:max-w-[600px]">
        <DialogHeader>
          <DialogTitle>Import Data</DialogTitle>
          <DialogDescription>
            Upload a file to import data into your table.
          </DialogDescription>
        </DialogHeader>

        {!selectedFile && !importing && !result && renderFileInput()}
        {selectedFile && !importing && !result && renderPreview()}
        {importing && renderProgress()}
        {result && renderResult()}

        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => {
              if (result) {
                resetImport()
                setResult(null)
              } else {
                setIsOpen(false)
              }
            }}
          >
            {result ? 'Import Another' : 'Cancel'}
          </Button>

          {selectedFile && !importing && !result && (
            <Button
              type="button"
              onClick={handleImport}
              disabled={errors.length > 0 || !onImport}
            >
              <Upload className="mr-2 h-4 w-4" />
              Import Data
            </Button>
          )}

          {result && result.success && (
            <Button
              type="button"
              onClick={() => setIsOpen(false)}
            >
              Close
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// Helper functions for parsing files
async function parseCSVPreview(file: File): Promise<PreviewData> {
  const text = await file.text()
  const lines = text.split('\n').filter(line => line.trim())

  if (lines.length === 0) {
    throw new Error('File is empty')
  }

  const headers = lines[0].split(',').map(h => h.trim().replace(/"/g, ''))
  const rows = lines.slice(1, 6).map(line => {
    const values = line.split(',').map(v => v.trim().replace(/"/g, ''))
    return headers.reduce((obj, header, index) => {
      obj[header] = values[index] || ''
      return obj
    }, {} as Record<string, unknown>)
  })

  return {
    headers,
    rows,
    totalRows: lines.length - 1,
  }
}

async function parseJSONPreview(file: File): Promise<PreviewData> {
  const text = await file.text()
  const data = JSON.parse(text)
  const items = Array.isArray(data) ? data : [data]

  if (items.length === 0) {
    throw new Error('No data found in file')
  }

  const headers = Object.keys(items[0])
  const rows = items.slice(0, 5)

  return {
    headers,
    rows,
    totalRows: items.length,
  }
}