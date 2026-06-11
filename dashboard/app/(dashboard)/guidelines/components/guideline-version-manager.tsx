"use client"

import * as React from "react"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import {
  Calendar,
  CheckCircle2,
  FileText,
  FolderUp,
  Loader2,
  Plus,
  RefreshCw,
  ShieldCheck,
  Upload,
} from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { EmptyState } from "@/components/ui/empty-state"
import { FileUpload } from "@/components/ui/file-upload"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { CardLoading } from "@/components/ui/loading-state"
import { showToast } from "@/lib/toast"
import {
  CreateGuidelineVersionInput,
  GuidelineDocumentRecord,
  GuidelineDocumentsService,
  GuidelineVersionRecord,
} from "@/services/guideline-documents.service"

const guidelineDocumentsQueryKey = ["v2-guideline-documents"]

function formatDate(value?: string | null) {
  if (!value) return "Not set"

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return value
  }

  return date.toLocaleDateString()
}

function VersionStatusBadge({ version }: { version: GuidelineVersionRecord }) {
  const isReady = Boolean(version.original_file_key && version.html_file_key && version.markdown_file_key)
  const isPublished = version.status === "published"

  if (isPublished) {
    return <Badge variant="default">Published</Badge>
  }

  if (isReady) {
    return <Badge variant="outline">Ready to Publish</Badge>
  }

  if (version.original_file_key) {
    return <Badge variant="secondary">Uploaded, Processing Pending</Badge>
  }

  return <Badge variant="secondary">Draft</Badge>
}

function CreateVersionDialog({
  document,
  open,
  submitting,
  onOpenChange,
  onSubmit,
}: {
  document: GuidelineDocumentRecord | null
  open: boolean
  submitting: boolean
  onOpenChange: (open: boolean) => void
  onSubmit: (payload: CreateGuidelineVersionInput) => Promise<void>
}) {
  const [version, setVersion] = React.useState("")
  const [publicationDate, setPublicationDate] = React.useState("")
  const [reviewDate, setReviewDate] = React.useState("")

  React.useEffect(() => {
    if (!open) {
      setVersion("")
      setPublicationDate("")
      setReviewDate("")
    }
  }, [open])

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create Guideline Version</DialogTitle>
          <DialogDescription>
            Add a version record for {document?.title || "this guideline"} before uploading the PDF.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="version-number">Version</Label>
            <Input
              id="version-number"
              placeholder="2026.1"
              value={version}
              onChange={(event) => setVersion(event.target.value)}
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="publication-date">Publication Date</Label>
              <Input
                id="publication-date"
                type="date"
                value={publicationDate}
                onChange={(event) => setPublicationDate(event.target.value)}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="review-date">Review Date</Label>
              <Input
                id="review-date"
                type="date"
                value={reviewDate}
                onChange={(event) => setReviewDate(event.target.value)}
              />
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={submitting}>
            Cancel
          </Button>
          <Button
            onClick={() =>
              onSubmit({
                version: version.trim(),
                publication_date: publicationDate || undefined,
                review_date: reviewDate || undefined,
              })
            }
            disabled={submitting || !version.trim()}
          >
            {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
            Create Version
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function UploadVersionDialog({
  version,
  open,
  submitting,
  onOpenChange,
  onSubmit,
}: {
  version: GuidelineVersionRecord | null
  open: boolean
  submitting: boolean
  onOpenChange: (open: boolean) => void
  onSubmit: (file: File) => Promise<void>
}) {
  const [file, setFile] = React.useState<File | null>(null)

  React.useEffect(() => {
    if (!open) {
      setFile(null)
    }
  }, [open])

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Upload Guideline PDF</DialogTitle>
          <DialogDescription>
            Upload the source PDF for version {version?.version || ""}. The backend will queue ingestion after upload.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-2">
          <Label>PDF File</Label>
          <FileUpload
            value={file || undefined}
            onValueChange={setFile}
            accept="application/pdf,.pdf"
            maxSize={100}
            placeholder="Choose guideline PDF or drag and drop"
          />
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={submitting}>
            Cancel
          </Button>
          <Button onClick={() => file && onSubmit(file)} disabled={submitting || !file}>
            {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" />}
            Upload PDF
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

export function GuidelineVersionManager() {
  const queryClient = useQueryClient()
  const [createDialogDocument, setCreateDialogDocument] = React.useState<GuidelineDocumentRecord | null>(null)
  const [uploadDialogVersion, setUploadDialogVersion] = React.useState<GuidelineVersionRecord | null>(null)
  const [submittingAction, setSubmittingAction] = React.useState<string | null>(null)

  const documentsQuery = useQuery({
    queryKey: guidelineDocumentsQueryKey,
    queryFn: () => GuidelineDocumentsService.listDocuments(),
  })

  const documents = documentsQuery.data?.items || []

  const refreshDocuments = React.useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: guidelineDocumentsQueryKey })
  }, [queryClient])

  const handleCreateVersion = React.useCallback(
    async (payload: CreateGuidelineVersionInput) => {
      if (!createDialogDocument) return

      setSubmittingAction("create-version")
      try {
        await GuidelineDocumentsService.createVersion(createDialogDocument.id, payload)
        showToast.success("Version created", "The new guideline version is ready for PDF upload.")
        setCreateDialogDocument(null)
        await refreshDocuments()
      } catch (error) {
        const message = error instanceof Error ? error.message : "Failed to create guideline version"
        showToast.error("Create version failed", message)
      } finally {
        setSubmittingAction(null)
      }
    },
    [createDialogDocument, refreshDocuments]
  )

  const handleUploadPdf = React.useCallback(
    async (file: File) => {
      if (!uploadDialogVersion) return

      setSubmittingAction(`upload:${uploadDialogVersion.id}`)
      try {
        const job = await GuidelineDocumentsService.uploadVersionPdf(uploadDialogVersion.id, file)
        showToast.success(
          "PDF uploaded",
          `Ingestion job queued with status: ${job.status}. Publish after extraction completes.`
        )
        setUploadDialogVersion(null)
        await refreshDocuments()
      } catch (error) {
        const message = error instanceof Error ? error.message : "Failed to upload PDF"
        showToast.error("Upload failed", message)
      } finally {
        setSubmittingAction(null)
      }
    },
    [refreshDocuments, uploadDialogVersion]
  )

  const handlePublishVersion = React.useCallback(
    async (version: GuidelineVersionRecord) => {
      setSubmittingAction(`publish:${version.id}`)
      try {
        await GuidelineDocumentsService.publishVersion(version.id)
        showToast.success("Version published", `Guideline version ${version.version} is now published.`)
        await refreshDocuments()
      } catch (error) {
        const message = error instanceof Error ? error.message : "Failed to publish guideline version"
        showToast.error("Publish failed", message)
      } finally {
        setSubmittingAction(null)
      }
    },
    [refreshDocuments]
  )

  return (
    <>
      <Card>
        <CardHeader className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="space-y-1">
            <CardTitle>Guideline Documents & Versions</CardTitle>
            <CardDescription>
              Upload source PDFs to version records, then publish versions after ingestion completes.
            </CardDescription>
          </div>
          <Button
            variant="outline"
            onClick={() => documentsQuery.refetch()}
            disabled={documentsQuery.isFetching}
          >
            {documentsQuery.isFetching ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <RefreshCw className="h-4 w-4" />
            )}
            Refresh
          </Button>
        </CardHeader>

        <CardContent>
          {documentsQuery.isLoading ? (
            <CardLoading message="Loading guideline documents..." />
          ) : documentsQuery.isError ? (
            <EmptyState
              icon={FileText}
              title="Failed to load guideline documents"
              description={
                documentsQuery.error instanceof Error
                  ? documentsQuery.error.message
                  : "The dashboard could not load guideline documents from the v2 API."
              }
              action={{
                label: "Retry",
                onClick: () => documentsQuery.refetch(),
              }}
            />
          ) : documents.length === 0 ? (
            <EmptyState
              icon={FileText}
              title="No guideline documents found"
              description="Create or import guideline documents first, then manage version uploads and publishing here."
            />
          ) : (
            <div className="space-y-4">
              {documents.map((document) => (
                <div key={document.id} className="rounded-xl border p-4">
                  <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                    <div className="space-y-2">
                      <div className="flex flex-wrap items-center gap-2">
                        <h3 className="text-lg font-semibold">{document.title}</h3>
                        {document.current_version_id ? (
                          <Badge variant="outline">Current version set</Badge>
                        ) : (
                          <Badge variant="secondary">No current version</Badge>
                        )}
                      </div>
                      <div className="flex flex-wrap gap-2 text-sm text-muted-foreground">
                        <span>{document.program_area || "No program area"}</span>
                        <span>{document.language || "en"}</span>
                        {document.country ? <span>{document.country}</span> : null}
                        {document.source_org ? <span>{document.source_org}</span> : null}
                      </div>
                      {document.description ? (
                        <p className="max-w-3xl text-sm text-muted-foreground">{document.description}</p>
                      ) : null}
                    </div>

                    <Button variant="outline" onClick={() => setCreateDialogDocument(document)}>
                      <Plus className="h-4 w-4" />
                      New Version
                    </Button>
                  </div>

                  <div className="mt-4 space-y-3">
                    {document.versions.length === 0 ? (
                      <div className="rounded-lg border border-dashed px-4 py-6 text-sm text-muted-foreground">
                        No versions yet. Create one before uploading a PDF.
                      </div>
                    ) : (
                      document.versions.map((version) => {
                        const isPublishPending = submittingAction === `publish:${version.id}`
                        const isUploadPending = submittingAction === `upload:${version.id}`
                        const canPublish =
                          version.status !== "published" &&
                          Boolean(version.original_file_key && version.html_file_key && version.markdown_file_key)

                        return (
                          <div
                            key={version.id}
                            className="flex flex-col gap-4 rounded-lg border bg-muted/20 p-4 xl:flex-row xl:items-center xl:justify-between"
                          >
                            <div className="space-y-2">
                              <div className="flex flex-wrap items-center gap-2">
                                <span className="text-base font-medium">Version {version.version}</span>
                                {document.current_version_id === version.id ? (
                                  <Badge variant="default">Current</Badge>
                                ) : null}
                                <VersionStatusBadge version={version} />
                              </div>

                              <div className="flex flex-wrap gap-4 text-sm text-muted-foreground">
                                <span className="inline-flex items-center gap-1">
                                  <Calendar className="h-4 w-4" />
                                  Published: {formatDate(version.publication_date)}
                                </span>
                                <span className="inline-flex items-center gap-1">
                                  <Calendar className="h-4 w-4" />
                                  Review: {formatDate(version.review_date)}
                                </span>
                                <span className="inline-flex items-center gap-1">
                                  <FolderUp className="h-4 w-4" />
                                  PDF: {version.original_file_key ? "uploaded" : "missing"}
                                </span>
                                <span className="inline-flex items-center gap-1">
                                  <CheckCircle2 className="h-4 w-4" />
                                  Extracted: {version.html_file_key && version.markdown_file_key ? "ready" : "pending"}
                                </span>
                              </div>
                            </div>

                            <div className="flex flex-wrap gap-2">
                              <Button
                                variant="outline"
                                onClick={() => setUploadDialogVersion(version)}
                                disabled={isUploadPending}
                              >
                                {isUploadPending ? (
                                  <Loader2 className="h-4 w-4 animate-spin" />
                                ) : (
                                  <Upload className="h-4 w-4" />
                                )}
                                Upload PDF
                              </Button>
                              <Button
                                onClick={() => handlePublishVersion(version)}
                                disabled={!canPublish || isPublishPending}
                              >
                                {isPublishPending ? (
                                  <Loader2 className="h-4 w-4 animate-spin" />
                                ) : (
                                  <ShieldCheck className="h-4 w-4" />
                                )}
                                Publish
                              </Button>
                            </div>
                          </div>
                        )
                      })
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      <CreateVersionDialog
        document={createDialogDocument}
        open={Boolean(createDialogDocument)}
        submitting={submittingAction === "create-version"}
        onOpenChange={(open) => {
          if (!open) setCreateDialogDocument(null)
        }}
        onSubmit={handleCreateVersion}
      />

      <UploadVersionDialog
        version={uploadDialogVersion}
        open={Boolean(uploadDialogVersion)}
        submitting={Boolean(uploadDialogVersion && submittingAction === `upload:${uploadDialogVersion.id}`)}
        onOpenChange={(open) => {
          if (!open) setUploadDialogVersion(null)
        }}
        onSubmit={handleUploadPdf}
      />
    </>
  )
}
