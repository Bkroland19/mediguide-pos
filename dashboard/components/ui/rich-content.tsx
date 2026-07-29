import * as React from "react"
import sanitizeHtml from "sanitize-html"
import { cn } from "@/lib/utils"

interface RichContentProps extends React.HTMLAttributes<HTMLDivElement> {
  html?: string | null
  fallback?: React.ReactNode
}

export function RichContent({ html, fallback = null, className, ...rest }: RichContentProps) {
  if (!html || !html.trim()) {
    return fallback ? <div className={cn("text-muted-foreground", className)} {...rest}>{fallback}</div> : null
  }

  const sanitizedHtml = sanitizeHtml(html, {
    allowedTags: sanitizeHtml.defaults.allowedTags.concat([
      "img",
      "h1",
      "h2",
      "h3",
      "h4",
      "h5",
      "h6",
    ]),
    allowedAttributes: {
      ...sanitizeHtml.defaults.allowedAttributes,
      "*": ["class"],
      a: ["href", "name", "target", "rel", "title"],
      img: ["src", "alt", "title", "width", "height"],
    },
    allowedSchemes: ["http", "https", "mailto", "tel"],
    transformTags: {
      a: sanitizeHtml.simpleTransform("a", {
        rel: "noopener noreferrer",
      }),
    },
  })

  return (
    <div
      className={cn("rich-content text-foreground leading-relaxed", className)}
      dangerouslySetInnerHTML={{ __html: sanitizedHtml }}
      {...rest}
    />
  )
}
