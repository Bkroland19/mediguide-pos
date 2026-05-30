"use client"

function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob)
  const link = document.createElement("a")
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}

function escapeCsvValue(value: unknown): string {
  if (value === null || value === undefined) {
    return '""'
  }

  const normalized = Array.isArray(value)
    ? value.join(", ")
    : typeof value === "object"
      ? JSON.stringify(value)
      : String(value)

  return `"${normalized.replace(/"/g, '""')}"`
}

export function downloadJson(data: unknown, filename: string) {
  const blob = new Blob([JSON.stringify(data, null, 2)], {
    type: "application/json",
  })
  triggerDownload(blob, filename)
}

export function downloadCsv<T extends Record<string, unknown>>(
  rows: T[],
  columns: Array<{ key: keyof T; label: string }>,
  filename: string
) {
  const csv = [
    columns.map((column) => escapeCsvValue(column.label)).join(","),
    ...rows.map((row) =>
      columns.map((column) => escapeCsvValue(row[column.key])).join(",")
    ),
  ].join("\n")

  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" })
  triggerDownload(blob, filename)
}
