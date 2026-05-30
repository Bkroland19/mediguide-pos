"use client"

import * as React from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { usePermissionContext } from "@/lib/permission-context"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import {
  Download,
  Upload,
  RefreshCw,
  AlertTriangle,
  CheckCircle,
  Database,
  Trash2,
  Plus,
  FileArchive
} from "lucide-react"
import { PageHeader } from "@/components/ui/page-header"
import { backupService } from "@/services/backup.service"
import type { BackupFile, BackupStats } from "@/types/backup"

export default function BackupPage() {
  const router = useRouter()
  const { hasPermission, loading } = usePermissionContext()
  const [backups, setBackups] = React.useState<BackupFile[]>([])
  const [stats, setStats] = React.useState<BackupStats | null>(null)
  const [isLoading, setIsLoading] = React.useState(true)

  React.useEffect(() => {
    if (loading) return
    if (!hasPermission("system_settings", "read:any")) {
      router.replace("/")
    }
  }, [loading, hasPermission, router])
  const [isUploading, setIsUploading] = React.useState(false)
  const [isCreating, setIsCreating] = React.useState(false)
  const [dragActive, setDragActive] = React.useState(false)
  const [newBackupName, setNewBackupName] = React.useState("")
  const fileInputRef = React.useRef<HTMLInputElement>(null)

  // Load data on component mount
  const loadData = React.useCallback(async () => {
    try {
      setIsLoading(true)
      const [backupsResponse, backupStats] = await Promise.all([
        backupService.listBackups(),
        backupService.getBackupStats()
      ])
      setBackups(backupsResponse.items as BackupFile[])
      setStats(backupStats)
    } catch (err) {
      console.error('Failed to load backup data:', err)
    } finally {
      setIsLoading(false)
    }
  }, [])

  React.useEffect(() => {
    loadData()
  }, [loadData])

  // Handle file upload
  const handleFileUpload = React.useCallback(async (file: File) => {
    if (!file.name.endsWith('.zip')) {
      return
    }
    
    try {
      setIsUploading(true)
      const result = await backupService.uploadBackup({ file })
      if (result.success) {
        await loadData()
      }
    } catch (err) {
      console.error('Upload failed:', err)
    } finally {
      setIsUploading(false)
    }
  }, [loadData])

  // Handle file drag and drop
  const handleDrag = React.useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true)
    } else if (e.type === "dragleave") {
      setDragActive(false)
    }
  }, [])

  const handleDrop = React.useCallback(async (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setDragActive(false)
    
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      const file = e.dataTransfer.files[0]
      await handleFileUpload(file)
    }
  }, [handleFileUpload])

  const handleFileInputChange = React.useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      await handleFileUpload(e.target.files[0])
    }
  }, [handleFileUpload])

  const handleCreateBackup = React.useCallback(async () => {
    try {
      setIsCreating(true)
      const result = await backupService.createBackup({ name: newBackupName || undefined })
      if (result.success) {
        setNewBackupName("")
        await loadData()
      }
    } catch (err) {
      console.error('Create backup failed:', err)
    } finally {
      setIsCreating(false)
    }
  }, [newBackupName, loadData])

  const handleDownloadBackup = React.useCallback(async (key: string) => {
    try {
      const downloadUrl = await backupService.downloadBackup({ key })
      window.open(downloadUrl, '_blank')
    } catch (err) {
      console.error('Download failed:', err)
    }
  }, [])

  const handleRestoreBackup = React.useCallback(async (key: string) => {
    try {
      const result = await backupService.restoreBackup({ key })
      if (result.success) {
        // Note: Server will restart after restore
      }
    } catch (err) {
      console.error('Restore failed:', err)
    }
  }, [])

  const handleDeleteBackup = React.useCallback(async (key: string) => {
    try {
      const result = await backupService.deleteBackup(key)
      if (result.success) {
        await loadData()
      }
    } catch (err) {
      console.error('Delete failed:', err)
    }
  }, [loadData])

  if (isLoading) {
    return (
      <div className="space-y-6">
        <PageHeader
          title="Backup & Restore"
          description="Database backup management"
        />
        <div className="flex items-center justify-center h-64">
          <RefreshCw className="h-8 w-8 animate-spin" />
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Backup & Restore"
        description="Database backup and restore operations"
        actions={[
          {
            label: "Refresh",
            onClick: loadData,
            icon: <RefreshCw className="h-4 w-4" />,
            variant: "outline"
          }
        ]}
      />

      {/* Backup Statistics */}
      {stats && (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Backups</CardTitle>
              <FileArchive className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.totalBackups}</div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Storage Used</CardTitle>
              <Database className="h-4 w-4 text-blue-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{backupService.formatFileSize(stats.totalSize)}</div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Latest Backup</CardTitle>
              <CheckCircle className="h-4 w-4 text-green-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {stats.latestBackup ? backupService.formatDate(stats.latestBackup.modified) : "None"}
              </div>
              {stats.latestBackup && (
                <p className="text-xs text-muted-foreground">
                  {backupService.formatFileSize(stats.latestBackup.size)}
                </p>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Oldest Backup</CardTitle>
              <FileArchive className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {stats.oldestBackup ? backupService.formatDate(stats.oldestBackup.modified) : "None"}
              </div>
              {stats.oldestBackup && (
                <p className="text-xs text-muted-foreground">
                  {backupService.formatFileSize(stats.oldestBackup.size)}
                </p>
              )}
            </CardContent>
          </Card>
        </div>
      )}

      {/* Create Backup Section */}
      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Create New Backup</CardTitle>
            <CardDescription>Generate a new database backup</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-2">
              <Label htmlFor="backup-name">Backup Name (Optional)</Label>
              <Input
                id="backup-name"
                value={newBackupName}
                onChange={(e) => setNewBackupName(e.target.value)}
                placeholder="e.g., Manual Backup"
              />
            </div>
            <Button
              onClick={handleCreateBackup}
              disabled={isCreating}
              className="w-full"
            >
              {isCreating ? (
                <RefreshCw className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Plus className="mr-2 h-4 w-4" />
              )}
              {isCreating ? "Creating..." : "Create Backup"}
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Upload & Restore</CardTitle>
            <CardDescription>Upload a backup file to restore</CardDescription>
          </CardHeader>
          <CardContent>
            <div
              className={`border-2 border-dashed rounded-lg p-8 text-center transition-colors ${
                dragActive
                  ? "border-primary bg-primary/5"
                  : "border-muted-foreground/25 hover:border-muted-foreground/50"
              }`}
              onDragEnter={handleDrag}
              onDragLeave={handleDrag}
              onDragOver={handleDrag}
              onDrop={handleDrop}
            >
              {isUploading ? (
                <div className="space-y-2">
                  <RefreshCw className="mx-auto h-8 w-8 animate-spin" />
                  <p className="text-sm">Uploading backup...</p>
                </div>
              ) : (
                <div className="space-y-4">
                  <Upload className="mx-auto h-8 w-8 text-muted-foreground" />
                  <div className="space-y-2">
                    <p className="text-sm font-medium">Drop backup file here or click to browse</p>
                    <p className="text-xs text-muted-foreground">Only .zip files are supported</p>
                  </div>
                  <Button
                    variant="outline"
                    onClick={() => fileInputRef.current?.click()}
                    disabled={isUploading}
                  >
                    Browse Files
                  </Button>
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept=".zip"
                    onChange={handleFileInputChange}
                    className="hidden"
                  />
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Backup List */}
      <Card>
        <CardHeader>
          <CardTitle>Available Backups</CardTitle>
          <CardDescription>Manage existing database backups</CardDescription>
        </CardHeader>
        <CardContent>
          {backups.length === 0 ? (
            <div className="text-center py-8">
              <FileArchive className="mx-auto h-8 w-8 text-muted-foreground mb-2" />
              <p className="text-sm text-muted-foreground">No backups available</p>
            </div>
          ) : (
            <div className="space-y-3">
              {backups.map((backup) => (
                <div key={backup.key} className="flex items-center justify-between p-4 border rounded-lg">
                  <div className="flex items-center space-x-4">
                    <FileArchive className="h-8 w-8 text-blue-500" />
                    <div>
                      <h4 className="font-semibold">{backup.key}</h4>
                      <div className="flex items-center space-x-4 text-sm text-muted-foreground">
                        <span>{backupService.formatFileSize(backup.size)}</span>
                        <span>{backupService.formatDate(backup.modified)}</span>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center space-x-2">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleDownloadBackup(backup.key)}
                    >
                      <Download className="h-4 w-4" />
                    </Button>
                    <Dialog>
                      <DialogTrigger asChild>
                        <Button variant="ghost" size="sm">
                          <Upload className="h-4 w-4" />
                        </Button>
                      </DialogTrigger>
                      <DialogContent>
                        <DialogHeader>
                          <DialogTitle>Restore Backup</DialogTitle>
                          <DialogDescription>
                            Are you sure you want to restore from this backup? This will overwrite current data and restart the server.
                          </DialogDescription>
                        </DialogHeader>
                        <Alert>
                          <AlertTriangle className="h-4 w-4" />
                          <AlertDescription>
                            This action cannot be undone. The server will restart after restoration.
                          </AlertDescription>
                        </Alert>
                        <div className="flex justify-end space-x-2">
                          <Button variant="outline">Cancel</Button>
                          <Button
                            variant="destructive"
                            onClick={() => handleRestoreBackup(backup.key)}
                          >
                            Restore
                          </Button>
                        </div>
                      </DialogContent>
                    </Dialog>
                    <Dialog>
                      <DialogTrigger asChild>
                        <Button variant="ghost" size="sm">
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </DialogTrigger>
                      <DialogContent>
                        <DialogHeader>
                          <DialogTitle>Delete Backup</DialogTitle>
                          <DialogDescription>
                            Are you sure you want to delete this backup? This action cannot be undone.
                          </DialogDescription>
                        </DialogHeader>
                        <div className="flex justify-end space-x-2">
                          <Button variant="outline">Cancel</Button>
                          <Button
                            variant="destructive"
                            onClick={() => handleDeleteBackup(backup.key)}
                          >
                            Delete
                          </Button>
                        </div>
                      </DialogContent>
                    </Dialog>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}