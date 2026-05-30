"use client"

import { useState, useEffect, use } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { useQueryClient } from "@tanstack/react-query"
import { zodResolver } from "@hookform/resolvers/zod"
import { useForm } from "react-hook-form"
import { z } from "zod"
import { Save } from "lucide-react"
import { PageHeader } from "@/components/ui/page-header"
import { Card, CardContent } from "@/components/ui/card"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { RichTextEditor } from "@/components/ui/rich-text-editor"
import { LoadingState } from "@/components/ui/loading-state"
import { GenericPagesService } from "@/services/generic-pages.service"
import { genericPageQueryKey } from "@/hooks/use-generic-page"
import { showToast } from "@/lib/toast"
import type { GenericPageContent } from "@/types/generic-pages"
import { usePermissionContext } from "@/lib/permission-context"

const createFormSchema = (hasKey: boolean) => z.object({
  title: hasKey ? z.string().min(1, "Title is required").max(255, "Title is too long") : z.string().optional(),
  content: z.string().min(1, "Content is required"),
})

type FormData = z.infer<ReturnType<typeof createFormSchema>>

export default function EditContentPage({ params }: { params: Promise<{ pageKey: string }> }) {
  const router = useRouter()
  const searchParams = useSearchParams()
  const resolvedParams = use(params)
  const queryClient = useQueryClient()
  const { hasPermission, loading: permLoading } = usePermissionContext()

  useEffect(() => {
    if (permLoading) return
    if (!hasPermission("content", "update:any")) {
      const returnTo = searchParams.get("returnTo") || `/lab-test-menu`
      router.replace(returnTo)
    }
  }, [permLoading, hasPermission, router, searchParams])

  const contentKey = searchParams.get("contentKey")
  const returnTo = searchParams.get("returnTo") || `/lab-test-menu`
  const hasKey = Boolean(contentKey)
  
  const [loading, setLoading] = useState(false)
  const [initialLoading, setInitialLoading] = useState(true)
  const [pageExists, setPageExists] = useState(false)
  const [existingContent, setExistingContent] = useState<GenericPageContent | string | null>(null)

  const form = useForm<FormData>({
    resolver: zodResolver(createFormSchema(hasKey)),
    defaultValues: { title: "", content: undefined },
  })

  // Load existing content
  useEffect(() => {
    const loadContent = async () => {
      try {
        const page = await GenericPagesService.getPageByKey(resolvedParams.pageKey)
        
        if (!page) {
          setPageExists(false)
          return
        }

        setPageExists(true)

        if (hasKey && contentKey) {
          const content = page.content?.[contentKey] as GenericPageContent
          if (content) {
            setExistingContent(content)
            form.reset({ title: content.title || "", content: content.content || "" })
          } else {
            showToast.error("Content Not Found", `Content section "${contentKey}" does not exist`)
            router.push(returnTo)
            return
          }
        } else {
          const content = typeof page.content === 'string' ? page.content : ""
          setExistingContent(content)
          form.reset({ content: content || "" })
        }
      } catch (error) {
        console.error("Error loading content:", error)
        setPageExists(false)
      } finally {
        setInitialLoading(false)
      }
    }
    
    loadContent()
  }, [resolvedParams.pageKey, contentKey, hasKey, form, returnTo, router])

  const onSubmit = async (data: FormData) => {
    setLoading(true)
    try {
      if (hasKey && contentKey) {
        await GenericPagesService.updateContent(resolvedParams.pageKey, contentKey, {
          title: data.title || "",
          content: data.content
        })
      } else {
        await GenericPagesService.updatePageContent(resolvedParams.pageKey, data.content)
      }
      
      showToast.success("Content Updated", `${hasKey ? "Content section" : "Page content"} has been updated successfully`)
      await queryClient.invalidateQueries({ queryKey: genericPageQueryKey(resolvedParams.pageKey) })
      router.push(returnTo)
    } catch (error) {
      showToast.error("Update Failed", error instanceof Error ? error.message : "Failed to update content")
    } finally {
      setLoading(false)
    }
  }

  if (initialLoading) return <LoadingState message="Loading content..." />

  if (!pageExists) {
    return (
      <div className="space-y-6">
        <PageHeader
          title="Page Not Found"
          description="The requested page does not exist"
          showBackButton={true}
          onBack={() => router.push(returnTo)}
        />
        <Card>
          <CardContent className="text-center py-8">
            <p className="text-muted-foreground">
              The page &quot;{resolvedParams.pageKey}&quot; does not exist.
            </p>
          </CardContent>
        </Card>
      </div>
    )
  }

  if (hasKey && contentKey && !existingContent) {
    return (
      <div className="space-y-6">
        <PageHeader
          title="Content Not Found"
          description="The requested content section does not exist"
          showBackButton={true}
          onBack={() => router.push(returnTo)}
        />
        <Card>
          <CardContent className="text-center py-8">
            <p className="text-muted-foreground">
              Content section &quot;{contentKey}&quot; does not exist in page &quot;{resolvedParams.pageKey}&quot;.
            </p>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={hasKey ? `Edit ${contentKey}` : "Edit Content"}
        description={hasKey ? `Edit content section in ${resolvedParams.pageKey}` : `Edit content for ${resolvedParams.pageKey}`}
        showBackButton={true}
        onBack={() => router.push(returnTo)}
        actions={[
          {
            label: loading ? "Updating..." : "Update Content",
            onClick: () => form.handleSubmit(onSubmit)(),
            disabled: loading,
            icon: <Save className="h-4 w-4" />
          }
        ]}
      />

      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
          {hasKey && (
            <FormField
              control={form.control}
              name="title"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Section Title</FormLabel>
                  <FormControl>
                    <Input
                      placeholder="Enter section title"
                      {...field}
                      disabled={loading}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          )}

          <FormField
            control={form.control}
            name="content"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Content</FormLabel>
                <FormControl>
                  <div className="min-h-[400px]">
                    <RichTextEditor
                      value={field.value}
                      onChange={field.onChange}
                    />
                  </div>
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        </form>
      </Form>
    </div>
  )
}