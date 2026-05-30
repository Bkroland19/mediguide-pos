"use client"

import { Construction } from "lucide-react"

export function PageUnderConstruction({
  title = "Under Construction",
  description = "This page is being built. Check back soon.",
}: {
  title?: string
  description?: string
}) {
  return (
    <div className="flex h-full w-full items-center justify-center">
      <div className="flex max-w-md flex-col items-center text-center">
        <div className="mb-4 rounded-full bg-muted p-4">
          <Construction className="h-6 w-6 text-muted-foreground" />
        </div>
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        <p className="mt-2 text-sm text-muted-foreground">{description}</p>
      </div>
    </div>
  )
}
