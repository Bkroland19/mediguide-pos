"use client"

import * as React from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import { cn } from "@/lib/utils"

interface ColorPickerProps {
  value?: string
  onChange?: (color: string) => void
  disabled?: boolean
  className?: string
}

const defaultColors = [
  "#ef4444", "#f97316", "#f59e0b", "#eab308", "#84cc16", "#22c55e",
  "#10b981", "#14b8a6", "#06b6d4", "#0ea5e9", "#3b82f6", "#6366f1",
  "#8b5cf6", "#a855f7", "#d946ef", "#ec4899", "#f43f5e", "#64748b"
]

export function ColorPicker({ value, onChange, disabled, className }: ColorPickerProps) {
  const [open, setOpen] = React.useState(false)
  const [customColor, setCustomColor] = React.useState(value || "#000000")

  const handleColorSelect = (color: string) => {
    onChange?.(color)
    setCustomColor(color)
    setOpen(false)
  }

  const handleCustomColorChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const color = e.target.value
    setCustomColor(color)
    onChange?.(color)
  }

  return (
    <div className={cn("flex items-center space-x-2", className)}>
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            className="w-12 h-10 p-0"
            disabled={disabled}
          >
            <div
              className="w-6 h-6 rounded border border-muted-foreground/20"
              style={{ backgroundColor: value || "#000000" }}
            />
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-64 p-3">
          <div className="space-y-3">
            <Label>Select Color</Label>
            
            {/* Preset Colors */}
            <div className="grid grid-cols-6 gap-2">
              {defaultColors.map((color) => (
                <Button
                  key={color}
                  className="w-8 h-8 p-0 rounded border border-muted-foreground/20"
                  style={{ backgroundColor: color }}
                  onClick={() => handleColorSelect(color)}
                />
              ))}
            </div>

            {/* Custom Color Input */}
            <div className="space-y-2">
              <Label htmlFor="custom-color">Custom Color</Label>
              <div className="flex items-center space-x-2">
                <Input
                  id="custom-color"
                  type="color"
                  value={customColor}
                  onChange={handleCustomColorChange}
                  className="w-12 h-10 p-1 cursor-pointer"
                />
                <Input
                  type="text"
                  value={customColor}
                  onChange={handleCustomColorChange}
                  placeholder="#000000"
                  className="flex-1"
                />
              </div>
            </div>

            {/* Clear Color */}
            <Button
              variant="outline"
              size="sm"
              onClick={() => handleColorSelect("")}
              className="w-full"
            >
              Clear Color
            </Button>
          </div>
        </PopoverContent>
      </Popover>
      
      {/* Display selected color */}
      <div className="text-sm text-muted-foreground min-w-0 flex-1">
        {value || "No color selected"}
      </div>
    </div>
  )
}