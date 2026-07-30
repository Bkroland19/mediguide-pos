"use client"

import { Columns2, Eye, FilePenLine, RotateCcw, Save } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"

export type MarkdownViewMode = "edit" | "preview" | "split"

interface MarkdownEditorToolbarProps {
  mode: MarkdownViewMode
  canEdit: boolean
  dirty: boolean
  saving: boolean
  words: number
  characters: number
  onModeChange: (mode: MarkdownViewMode) => void
  onSave: () => void
  onRevert: () => void
}

export function MarkdownEditorToolbar({
  mode,
  canEdit,
  dirty,
  saving,
  words,
  characters,
  onModeChange,
  onSave,
  onRevert,
}: MarkdownEditorToolbarProps) {
  return (
    <div className="flex flex-col gap-3 border-b p-3 lg:flex-row lg:items-center lg:justify-between">
      <div className="flex flex-wrap items-center gap-2">
        <Tabs value={mode} onValueChange={(value) => onModeChange(value as MarkdownViewMode)}>
          <TabsList aria-label="Markdown view mode">
            {canEdit && (
              <TabsTrigger value="edit">
                <FilePenLine className="mr-2 h-4 w-4" />
                Edit
              </TabsTrigger>
            )}
            <TabsTrigger value="preview">
              <Eye className="mr-2 h-4 w-4" />
              Preview
            </TabsTrigger>
            {canEdit && (
              <TabsTrigger value="split">
                <Columns2 className="mr-2 h-4 w-4" />
                Split
              </TabsTrigger>
            )}
          </TabsList>
        </Tabs>
        <Badge variant={dirty ? "secondary" : "outline"}>
          {dirty ? "Unsaved changes" : "All changes saved"}
        </Badge>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <span className="mr-1 text-xs text-muted-foreground">
          {words.toLocaleString()} words · {characters.toLocaleString()} characters
        </span>
        {canEdit && (
          <>
            <Button variant="outline" size="sm" onClick={onRevert} disabled={!dirty || saving}>
              <RotateCcw className="mr-2 h-4 w-4" />
              Revert
            </Button>
            <Button size="sm" onClick={onSave} disabled={!dirty || saving}>
              <Save className="mr-2 h-4 w-4" />
              {saving ? "Saving…" : "Save"}
            </Button>
          </>
        )}
      </div>
    </div>
  )
}
