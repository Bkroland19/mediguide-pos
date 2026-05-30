"use client"

import * as React from "react"
import { Upload, File, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { cn } from "@/lib/utils"

interface FileUploadProps {
  value?: File | string
  onValueChange: (file: File | null) => void
  accept?: string
  maxSize?: number // in MB
  placeholder?: string
  disabled?: boolean
  className?: string
  error?: string
}

export function FileUpload({
  value,
  onValueChange,
  accept = "*",
  maxSize = 10,
  placeholder = "Choose file or drag and drop",
  disabled = false,
  className,
  error
}: FileUploadProps) {
  const [dragActive, setDragActive] = React.useState(false)
  const inputRef = React.useRef<HTMLInputElement>(null)

  const handleFile = React.useCallback((file: File) => {
    // Validate file size
    if (maxSize && file.size > maxSize * 1024 * 1024) {
      alert(`File size must be less than ${maxSize}MB`)
      return
    }

    onValueChange(file)
  }, [maxSize, onValueChange])

  const handleRemove = React.useCallback(() => {
    onValueChange(null)
    if (inputRef.current) {
      inputRef.current.value = ""
    }
  }, [onValueChange])

  const handleDrag = React.useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true)
    } else if (e.type === "dragleave") {
      setDragActive(false)
    }
  }, [])

  const handleDrop = React.useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setDragActive(false)

    if (disabled) return

    const files = e.dataTransfer.files
    if (files && files[0]) {
      handleFile(files[0])
    }
  }, [disabled, handleFile])

  const handleChange = React.useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    e.preventDefault()
    if (disabled) return

    const files = e.target.files
    if (files && files[0]) {
      handleFile(files[0])
    }
  }, [disabled, handleFile])

  const handleClick = React.useCallback(() => {
    if (!disabled) {
      inputRef.current?.click()
    }
  }, [disabled])

  const currentFile = (value && typeof value === 'object' && value.constructor && value.constructor.name === 'File') ? value : null
  const currentFileName = currentFile ? currentFile.name : (typeof value === 'string' ? value : null)

  return (
    <div className={cn("space-y-2", className)}>
      <div
        className={cn(
          "relative border-2 border-dashed rounded-lg p-6 transition-colors",
          dragActive ? "border-primary bg-primary/5" : "border-muted-foreground/25",
          disabled ? "opacity-50 cursor-not-allowed" : "cursor-pointer hover:border-primary/50",
          error ? "border-destructive" : "",
          currentFile ? "bg-muted/50" : ""
        )}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
        onClick={handleClick}
      >
        <Input
          ref={inputRef}
          type="file"
          accept={accept}
          onChange={handleChange}
          disabled={disabled}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
          tabIndex={-1}
        />

        <div className="flex flex-col items-center justify-center text-center">
          {currentFile ? (
            <>
              <File className="h-8 w-8 text-primary mb-2" />
              <p className="text-sm font-medium text-foreground mb-1">
                {currentFile.name}
              </p>
              <p className="text-xs text-muted-foreground mb-3">
                {(currentFile.size / 1024 / 1024).toFixed(2)} MB
              </p>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={(e) => {
                  e.stopPropagation()
                  handleRemove()
                }}
                disabled={disabled}
              >
                <X className="h-4 w-4 mr-1" />
                Remove
              </Button>
            </>
          ) : currentFileName ? (
            <>
              <File className="h-8 w-8 text-muted-foreground mb-2" />
              <p className="text-sm font-medium text-foreground mb-1">
                {currentFileName}
              </p>
              <p className="text-xs text-muted-foreground mb-3">
                Current file
              </p>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={(e) => {
                  e.stopPropagation()
                  handleRemove()
                }}
                disabled={disabled}
              >
                <X className="h-4 w-4 mr-1" />
                Clear
              </Button>
            </>
          ) : (
            <>
              <Upload className="h-8 w-8 text-muted-foreground mb-2" />
              <p className="text-sm font-medium text-foreground mb-1">
                {placeholder}
              </p>
              <p className="text-xs text-muted-foreground">
                Maximum file size: {maxSize}MB
              </p>
            </>
          )}
        </div>
      </div>

      {error && (
        <p className="text-sm text-destructive">{error}</p>
      )}
    </div>
  )
}