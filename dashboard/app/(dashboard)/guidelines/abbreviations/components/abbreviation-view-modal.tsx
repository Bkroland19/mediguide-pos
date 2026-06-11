"use client"

import * as React from "react"
import { format } from "date-fns"

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import type { AbbreviationsWithExpanded } from "@/types/expanded"

interface AbbreviationViewModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  abbreviation: AbbreviationsWithExpanded | null
  onEdit?: (abbreviation: AbbreviationsWithExpanded) => void
}

function Row({
  label,
  children,
}: {
  label: string
  children: React.ReactNode
}) {
  return (
    <div className="grid grid-cols-3 gap-3 py-2 border-b last:border-b-0">
      <div className="text-xs font-medium text-muted-foreground uppercase tracking-wide pt-0.5">
        {label}
      </div>
      <div className="col-span-2 text-sm break-words">{children}</div>
    </div>
  )
}

function formatDate(value?: string) {
  if (!value) return "—"
  try {
    return format(new Date(value), "PPpp")
  } catch {
    return value
  }
}

export function AbbreviationViewModal({
  open,
  onOpenChange,
  abbreviation,
  onEdit,
}: AbbreviationViewModalProps) {
  if (!abbreviation) return null

  const category = abbreviation.expand?.category
  const tags = abbreviation.expand?.tags ?? []
  const emptyDash = <span className="text-muted-foreground">—</span>

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[520px]">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <code className="text-base bg-muted px-2 py-0.5 rounded">
              {abbreviation.abbreviation}
            </code>
            <span className="text-base font-medium">{abbreviation.meaning}</span>
          </DialogTitle>
          <DialogDescription>Abbreviation details</DialogDescription>
        </DialogHeader>

        <div className="rounded-md border bg-muted/20 px-4 py-2">
          <Row label="Description">
            {abbreviation.description ? (
              <p className="whitespace-pre-wrap text-sm">{abbreviation.description}</p>
            ) : (
              emptyDash
            )}
          </Row>
          <Row label="Common Usage">
            <Badge variant={abbreviation.common_usage ? "default" : "secondary"}>
              {abbreviation.common_usage ? "Common" : "Standard"}
            </Badge>
          </Row>
          <Row label="Category">
            {category ? (
              category.name
            ) : abbreviation.category ? (
              <code className="text-xs">{abbreviation.category}</code>
            ) : (
              emptyDash
            )}
          </Row>
          <Row label="Tags">
            {tags.length > 0 ? (
              <div className="flex flex-wrap gap-1">
                {tags.map((tag) => (
                  <Badge key={tag.id} variant="outline" className="text-xs">
                    {tag.name}
                  </Badge>
                ))}
              </div>
            ) : (
              emptyDash
            )}
          </Row>
          <Row label="Usage Count">
            {typeof abbreviation.usageCount === "number"
              ? abbreviation.usageCount
              : 0}
          </Row>
          <Row label="Created">{formatDate(abbreviation.created)}</Row>
          <Row label="Updated">{formatDate(abbreviation.updated)}</Row>
          <Row label="ID">
            <code className="text-xs">{abbreviation.id}</code>
          </Row>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Close
          </Button>
          {onEdit && (
            <Button
              onClick={() => {
                onOpenChange(false)
                onEdit(abbreviation)
              }}
            >
              Edit Abbreviation
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
