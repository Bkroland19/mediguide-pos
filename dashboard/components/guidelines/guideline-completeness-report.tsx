"use client";

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { AlertTriangle, CheckCircle2, Download, FileSearch, Loader2 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { showToast } from "@/lib/toast";
import {
  guidelineDocumentsQueryKey,
  GuidelineDocumentsService,
} from "@/services/guideline-documents.service";

export function GuidelineCompletenessReport({ versionId }: { versionId: string }) {
  const [downloading, setDownloading] = React.useState<"json" | "csv" | null>(null);
  const report = useQuery({
    queryKey: [...guidelineDocumentsQueryKey, versionId, "completeness-report"],
    queryFn: () => GuidelineDocumentsService.getCompletenessReport(versionId),
    enabled: Boolean(versionId),
  });

  async function download(format: "json" | "csv") {
    setDownloading(format);
    try {
      await GuidelineDocumentsService.downloadCompletenessReport(versionId, format);
      showToast.success("Completeness report downloaded", `The read-only ${format.toUpperCase()} report is ready.`);
    } catch (error) {
      showToast.error("Report download failed", error instanceof Error ? error.message : "Try again.");
    } finally {
      setDownloading(null);
    }
  }

  if (report.isLoading) {
    return <Card><CardContent className="flex items-center gap-2 py-6 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" /> Loading completeness report…</CardContent></Card>;
  }
  if (report.isError || !report.data) {
    return (
      <Card className="border-destructive/40"><CardContent className="flex items-center justify-between gap-3 py-5 text-sm">
        <span className="flex items-center gap-2"><AlertTriangle className="h-4 w-4 text-destructive" /> The completeness report could not be loaded.</span>
        <Button size="sm" variant="outline" onClick={() => void report.refetch()}>Retry</Button>
      </CardContent></Card>
    );
  }

  const data = report.data;
  const metrics = [
    ["Reviewed blocks", `${data.reviewed_blocks} / ${data.active_blocks}`],
    ["Reviewed coverage", `${data.reviewed_percentage.toFixed(1)}%`],
    ["Structural sections", data.sections.total_sections],
    ["Sections reviewed", data.sections.reviewed_sections],
    ["Reviewed leaves", `${data.sections.reviewed_leaf_sections} / ${data.sections.leaf_sections}`],
    ["Empty leaves", data.sections.empty_leaf_sections],
  ] as const;

  return (
    <Card data-testid="completeness-report">
      <CardHeader className="pb-3">
        <CardTitle className="flex flex-wrap items-center justify-between gap-3 text-base">
          <span className="flex items-center gap-2"><FileSearch className="h-4 w-4" /> Publication completeness</span>
          <span className="flex items-center gap-2">
            <Badge variant="outline">Read only</Badge>
            <Button size="sm" variant="outline" onClick={() => void download("json")} disabled={downloading !== null}><Download className="mr-1 h-3.5 w-3.5" /> JSON</Button>
            <Button size="sm" variant="outline" onClick={() => void download("csv")} disabled={downloading !== null}><Download className="mr-1 h-3.5 w-3.5" /> CSV</Button>
          </span>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-2 sm:grid-cols-3 lg:grid-cols-6">
          {metrics.map(([label, value]) => <div key={label} className="rounded-md border p-3"><div className="text-xs text-muted-foreground">{label}</div><div className="mt-1 font-semibold">{value}</div></div>)}
        </div>
        <div className="grid gap-3 text-sm md:grid-cols-3">
          <Status label="Publication validation" ok={data.validation.valid} detail={data.validation.valid ? "All publication gates pass" : `${data.validation.errors.length} blocking issue(s)`} />
          <Status label="Reviewed fallback" ok={data.sources.reviewed_fallback_available} detail={data.sources.reviewed_fallback_available ? "Original PDF or offline fallback reviewed" : "No reviewed fallback available"} />
          <Status label="RAG readiness" ok={data.rag.ready} detail={data.rag.ready ? `${data.rag.reviewed_blocks_with_chunks} reviewed block chunks embedded` : `${data.rag.reviewed_blocks_without_chunks} blocks without chunks; ${data.rag.missing_reviewed_embeddings} reviewed embeddings missing`} />
        </div>
        <div className="overflow-x-auto rounded-md border">
          <table className="w-full text-left text-sm"><thead className="bg-muted/50 text-xs"><tr><th className="p-2">Block type</th><th className="p-2">Total</th><th className="p-2">Draft</th><th className="p-2">Reviewed</th><th className="p-2">Rejected</th></tr></thead>
            <tbody>{data.block_counts.map((row) => <tr key={row.block_type} className="border-t"><td className="p-2 font-medium">{row.block_type}</td><td className="p-2">{row.total}</td><td className="p-2">{row.draft}</td><td className="p-2">{row.reviewed}</td><td className="p-2">{row.rejected}</td></tr>)}</tbody>
          </table>
        </div>
        {data.current_comparison && !data.current_comparison.same_version ? (
          <div className="text-sm"><div className="mb-2 font-medium">Compared with current version {data.current_comparison.current_version}</div>
            <div className="flex flex-wrap gap-2">{data.current_comparison.metrics.map((metric) => <Badge key={metric.name} variant={metric.delta < 0 ? "destructive" : "outline"}>{metric.name.replaceAll("_", " ")}: {metric.current} → {metric.candidate}</Badge>)}</div>
          </div>
        ) : null}
        {data.empty_leaf_sections.length > 0 ? <details><summary className="cursor-pointer text-sm font-medium">Empty leaf sections ({data.empty_leaf_sections.length})</summary><ul className="mt-2 max-h-52 space-y-1 overflow-auto text-sm text-muted-foreground">{data.empty_leaf_sections.map((section) => <li key={section.id}>{section.title} · H{section.level}{section.review_exempt ? " · structural exception" : ""}</li>)}</ul></details> : null}
      </CardContent>
    </Card>
  );
}

function Status({ label, ok, detail }: { label: string; ok: boolean; detail: string }) {
  return <div className="rounded-md border p-3"><div className="flex items-center gap-2 font-medium">{ok ? <CheckCircle2 className="h-4 w-4 text-emerald-600" /> : <AlertTriangle className="h-4 w-4 text-amber-600" />}{label}</div><div className="mt-1 text-xs text-muted-foreground">{detail}</div></div>;
}
