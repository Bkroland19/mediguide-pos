"use client"

import { cn } from "@/lib/utils"
import { Loader2 } from "lucide-react"

export interface LoadingStateProps {
  message?: string
  size?: "sm" | "md" | "lg"
  variant?: "default" | "minimal" | "card"
  className?: string
  spinnerClassName?: string
}

const sizeStyles = {
  sm: {
    container: "min-h-[200px]",
    spinner: "h-6 w-6",
    text: "text-sm"
  },
  md: {
    container: "min-h-[400px]", 
    spinner: "h-8 w-8",
    text: "text-base"
  },
  lg: {
    container: "min-h-[600px]",
    spinner: "h-12 w-12", 
    text: "text-lg"
  }
}

const variantStyles = {
  default: "flex items-center justify-center",
  minimal: "flex items-center justify-center py-8",
  card: "flex items-center justify-center border rounded-lg bg-card"
}

export function LoadingState({
  message = "Loading...",
  size = "md",
  variant = "default",
  className,
  spinnerClassName
}: LoadingStateProps) {
  const styles = sizeStyles[size]
  
  return (
    <div className={cn(
      variantStyles[variant],
      styles.container,
      className
    )}>
      <div className="flex flex-col items-center justify-center space-y-4 text-center">
        <Loader2 
          className={cn(
            "animate-spin text-muted-foreground",
            styles.spinner,
            spinnerClassName
          )} 
        />
        <p className={cn(
          "text-muted-foreground font-medium",
          styles.text
        )}>
          {message}
        </p>
      </div>
    </div>
  )
}

// Pre-configured variants for common use cases
export const PageLoading = ({ message, className }: { message?: string; className?: string }) => (
  <LoadingState 
    message={message || "Loading page..."} 
    size="md" 
    variant="default"
    className={className}
  />
)

export const CardLoading = ({ message, className }: { message?: string; className?: string }) => (
  <LoadingState 
    message={message || "Loading content..."} 
    size="sm" 
    variant="card"
    className={className}
  />
)

export const MinimalLoading = ({ message, className }: { message?: string; className?: string }) => (
  <LoadingState 
    message={message || "Loading..."} 
    size="sm" 
    variant="minimal"
    className={className}
  />
)