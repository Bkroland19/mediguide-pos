"use client"

import * as React from "react"
import { useQueryClient } from "@tanstack/react-query"
import { zodResolver } from "@hookform/resolvers/zod"
import { useForm } from "react-hook-form"
import { z } from "zod"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Button } from "@/components/ui/button"
import { showToast } from "@/lib/toast"
import { GenericPagesService } from "@/services/generic-pages.service"
import { genericPageQueryKey } from "@/hooks/use-generic-page"
import type { GenericPageInfoDialogProps } from "@/types/generic-pages"

const formSchema = z.object({
  title: z.string().min(1, "Title is required").max(255, "Title is too long"),
  description: z.string().optional().or(z.literal("")),
})

type FormData = z.infer<typeof formSchema>

export function GenericPageInfoDialog({
  pageKey,
  currentTitle,
  currentDescription = "",
  open,
  onOpenChange,
  onSuccess
}: GenericPageInfoDialogProps) {
  const [loading, setLoading] = React.useState(false)
  const [isCreating, setIsCreating] = React.useState(false)
  const queryClient = useQueryClient()

  const form = useForm<FormData>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      title: currentTitle || "",
      description: currentDescription || "",
    },
  })

  // Reset form when dialog opens with new data and check if creating
  React.useEffect(() => {
    if (open) {
      form.reset({
        title: currentTitle || "",
        description: currentDescription || "",
      })
      
      // Check if we're in creation mode by checking if page exists
      GenericPagesService.getPageByKey(pageKey).then(page => {
        setIsCreating(!page)
      }).catch(() => {
        // If error getting page, assume we're creating
        setIsCreating(true)
      })
    }
  }, [open, currentTitle, currentDescription, form, pageKey])

  const onSubmit = async (data: FormData) => {
    setLoading(true)
    try {
      // Check if page exists, if not create it, otherwise update it
      const existingPage = await GenericPagesService.getPageByKey(pageKey)
      
      if (existingPage) {
        // Update existing page
        await GenericPagesService.updatePageInfo(
          pageKey,
          data.title,
          data.description
        )
        showToast.success(
          "Page Updated",
          "Page information has been updated successfully"
        )
      } else {
        // Create new page
        await GenericPagesService.createPage(
          pageKey,
          data.title,
          data.description
        )
        showToast.success(
          "Page Created",
          "Page has been created successfully"
        )
      }
      
      await queryClient.invalidateQueries({ queryKey: genericPageQueryKey(pageKey) })
      onSuccess()
      onOpenChange(false)
    } catch (error) {
      console.error("Error saving page info:", error)
      showToast.error(
        "Save Failed",
        error instanceof Error ? error.message : "Failed to save page information"
      )
    } finally {
      setLoading(false)
    }
  }

  const handleCancel = () => {
    form.reset({
      title: "",
      description: "",
    })
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>
            {isCreating ? "Create New Page" : "Edit Page Information"}
          </DialogTitle>
          <DialogDescription>
            {isCreating 
              ? "Create a new page with a custom title and description. This will set up the basic page structure."
              : "Update the page title and description. This information will be displayed in the page header."
            }
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="title"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Title</FormLabel>
                  <FormControl>
                    <Input 
                      placeholder={isCreating ? "Enter page title" : "Update page title"}
                      {...field} 
                      disabled={loading}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder={isCreating ? "Enter page description (optional)" : "Update page description"}
                      rows={3}
                      {...field}
                      disabled={loading}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <DialogFooter>
              <Button 
                type="button" 
                variant="outline" 
                onClick={handleCancel}
                disabled={loading}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={loading}>
                {loading 
                  ? (isCreating ? "Creating..." : "Updating...") 
                  : (isCreating ? "Create Page" : "Update Page")
                }
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}