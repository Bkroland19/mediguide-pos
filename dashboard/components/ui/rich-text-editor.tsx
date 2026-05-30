"use client"

import React from 'react'
import { Editor } from '@tinymce/tinymce-react'
import { cn } from '@/lib/utils'

interface RichTextEditorProps {
  value?: string
  onChange?: (value: string) => void
  onBlur?: () => void
  placeholder?: string
  height?: number
  disabled?: boolean
  className?: string
  error?: string
}

export function RichTextEditor({
  value = '',
  onChange,
  onBlur,
  placeholder = 'Start typing...',
  height = 400,
  disabled = false,
  className,
  error
}: RichTextEditorProps) {
  return (
    <div className={cn('space-y-2', className)}>
      <div className={cn(
        'border rounded-md overflow-hidden',
        error ? 'border-destructive' : 'border-input',
        disabled && 'opacity-50 cursor-not-allowed'
      )}>
        <Editor
          tinymceScriptSrc="/tinymce/tinymce.min.js"
          licenseKey="gpl"
          value={value}
          init={{
            height,
            menubar: false,
            plugins: [
              'advlist', 'autolink', 'lists', 'link', 'image', 'charmap', 'preview',
              'anchor', 'searchreplace', 'visualblocks', 'code', 'fullscreen',
              'insertdatetime', 'media', 'table', 'help', 'wordcount', 'codesample',
              'emoticons', 'nonbreaking', 'pagebreak', 'quickbars', 'visualchars'
            ],
            toolbar: [
              'undo redo | blocks fontsize | bold italic underline strikethrough | forecolor backcolor',
              'alignleft aligncenter alignright alignjustify | bullist numlist outdent indent',
              'link image media table | insertdatetime charmap emoticons | codesample code',
              'searchreplace visualblocks visualchars | pagebreak nonbreaking | fullscreen preview help'
            ].join(' | '),
            content_style: `
              body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
                font-size: 14px;
                line-height: 1.6;
                margin: 16px;
              }
            `,
            placeholder,
            branding: false,
            resize: false,
            statusbar: false,
            skin: 'oxide',
            content_css: 'default',
            // Set base URL for TinyMCE assets
            base_url: '/tinymce',
            suffix: '.min',
            // Community edition configuration
            promotion: false,
            
            // Table configuration
            table_toolbar: 'tableprops tabledelete | tableinsertrowbefore tableinsertrowafter tabledeleterow | tableinsertcolbefore tableinsertcolafter tabledeletecol',
            table_appearance_options: false,
            table_grid: false,
            table_class_list: [
              { title: 'None', value: '' },
              { title: 'Bordered Table', value: 'table-bordered' },
              { title: 'Striped Table', value: 'table-striped' }
            ],
            
            // Image configuration
            images_upload_handler: (blobInfo: { blob: () => Blob }) => {
              return new Promise<string>((resolve, reject) => {
                // For now, create a data URL - in production you'd upload to a server
                const reader = new FileReader()
                reader.onload = () => resolve(reader.result as string)
                reader.onerror = () => reject('Image upload failed')
                reader.readAsDataURL(blobInfo.blob())
              })
            },
            // images_upload_url: disabled for now - using custom handler
            automatic_uploads: true,
            paste_data_images: true,
            
            // Font options
            fontsize_formats: '8pt 10pt 12pt 14pt 16pt 18pt 24pt 36pt 48pt',
            font_family_formats: 'Arial=arial,helvetica,sans-serif; Times New Roman=times new roman,times,serif; Courier New=courier new,courier,monospace; Verdana=verdana,geneva,sans-serif; Georgia=georgia,times,serif',
            
            // Code sample configuration
            codesample_languages: [
              { text: 'HTML/XML', value: 'markup' },
              { text: 'JavaScript', value: 'javascript' },
              { text: 'CSS', value: 'css' },
              { text: 'PHP', value: 'php' },
              { text: 'Python', value: 'python' },
              { text: 'Java', value: 'java' },
              { text: 'C#', value: 'csharp' },
              { text: 'SQL', value: 'sql' }
            ],
            
            // Quick bars configuration
            quickbars_selection_toolbar: 'bold italic | quicklink h2 h3 blockquote',
            quickbars_insert_toolbar: 'quickimage quicktable',
            
            // Advanced features
            paste_as_text: false,
            paste_webkit_styles: 'color font-size font-family',
            contextmenu: 'link image table',
            autoresize_bottom_margin: 16
          }}
          onEditorChange={(content) => {
            onChange?.(content)
          }}
          onBlur={onBlur}
          disabled={disabled}
        />
      </div>
      {error && (
        <p className="text-sm text-destructive">{error}</p>
      )}
    </div>
  )
}

// Form wrapper component for easier integration
interface EditorFormWrapperProps {
  title: string
  description?: string
  value?: string
  onChange?: (value: string) => void
  placeholder?: string
  minHeight?: string
  error?: string
  className?: string
  disabled?: boolean
}

export function EditorFormWrapper({
  title,
  description,
  value,
  onChange,
  placeholder = "Start typing...",
  minHeight = "200px",
  error,
  className,
  disabled = false,
  ...props
}: EditorFormWrapperProps) {
  const heightPx = parseInt(minHeight) || 200

  return (
    <div className={cn("w-full space-y-4", className)} {...props}>
      <div>
        <h3 className="text-base font-medium">{title}</h3>
        {description && (
          <p className="text-sm text-muted-foreground mt-1">
            {description}
          </p>
        )}
      </div>
      <RichTextEditor
        value={value}
        onChange={onChange}
        placeholder={placeholder}
        height={heightPx}
        disabled={disabled}
        error={error}
      />
    </div>
  )
}