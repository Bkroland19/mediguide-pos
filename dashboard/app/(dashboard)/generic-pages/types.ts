import type { GenericPageContent } from "@/types/generic-pages"

/**
 * Content structure types for generic pages
 */
export interface ContentFormData {
  title?: string    // Optional - only for key-value structure
  content: string   // HTML content from WYSIWYG editor
}

/**
 * Content structure detection
 */
export type ContentStructure = "keyed" | "simple"

/**
 * Page parameters from URL
 */
export interface PageParams {
  pageKey: string
}

/**
 * Query parameters for content management
 */
export interface ContentQuery {
  contentKey?: string
  returnTo?: string
}

/**
 * Props for content form components
 */
export interface ContentFormProps {
  pageKey: string
  contentKey?: string
  existingContent?: GenericPageContent | string
  mode: "create" | "edit"
  onSuccess?: () => void
}