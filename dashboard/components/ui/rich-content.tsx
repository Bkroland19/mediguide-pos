import * as React from "react"
import { cn } from "@/lib/utils"

interface RichContentProps extends React.HTMLAttributes<HTMLDivElement> {
  html?: string | null
  fallback?: React.ReactNode
}

export function RichContent({ html, fallback = null, className, ...rest }: RichContentProps) {
  if (!html || !html.trim()) {
    return fallback ? <div className={cn("text-muted-foreground", className)} {...rest}>{fallback}</div> : null
  }

  return (
    <div
      className={cn("rich-content text-foreground leading-relaxed", className)}
      dangerouslySetInnerHTML={{ __html: html }}
      {...rest}
    />
  )
}
