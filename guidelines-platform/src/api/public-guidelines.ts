import { publicApiBaseUrl } from "../config";

export type PublicGuideline = {
  id: string;
  slug: string;
  title: string;
  description: string;
  country: string;
  source_org: string;
  program_area: string;
  language: string;
  publication_date: string;
  review_date: string;
  version: string;
  last_updated: string;
};

export type PublicGuidelinePage = {
  items: PublicGuideline[];
  page: number;
  per_page: number;
  total_items: number;
  total_pages: number;
};

type ApiEnvelope<T> = {
  success: boolean;
  data?: T;
  error?: string;
};

export type PublicGuidelineFilters = {
  search?: string;
  programArea?: string;
  country?: string;
  language?: string;
  page?: number;
  perPage?: number;
};

export type PublicMarkdown = {
  content: string;
  etag?: string;
  lastModified?: string;
  fromCache: boolean;
};

export type PublicApiErrorKind =
  | "not-found"
  | "timeout"
  | "network"
  | "server"
  | "invalid-response";

export class PublicApiError extends Error {
  readonly kind: PublicApiErrorKind;
  readonly status?: number;

  constructor(
    kind: PublicApiErrorKind,
    status?: number,
  ) {
    super(kind === "not-found" ? "Guideline not found" : "Unable to load guideline");
    this.name = "PublicApiError";
    this.kind = kind;
    this.status = status;
  }
}

const requestTimeoutMs = 12_000;
const markdownCache = new Map<string, PublicMarkdown>();
const maxCachedDocuments = 8;

function publicUrl(path: string, query?: URLSearchParams) {
  const suffix = query?.size ? `?${query.toString()}` : "";
  return `${publicApiBaseUrl}/api/public${path}${suffix}`;
}

async function request(
  url: string,
  options: RequestInit = {},
  externalSignal?: AbortSignal,
) {
  const controller = new AbortController();
  const timeout = globalThis.setTimeout(() => controller.abort("timeout"), requestTimeoutMs);
  const abort = () => controller.abort(externalSignal?.reason);
  externalSignal?.addEventListener("abort", abort, { once: true });

  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } catch (error) {
    if (controller.signal.aborted) {
      if (externalSignal?.aborted) throw error;
      throw new PublicApiError("timeout");
    }
    throw new PublicApiError("network");
  } finally {
    globalThis.clearTimeout(timeout);
    externalSignal?.removeEventListener("abort", abort);
  }
}

async function requestJson<T>(url: string, signal?: AbortSignal): Promise<T> {
  const response = await request(url, { headers: { Accept: "application/json" } }, signal);
  if (response.status === 404) throw new PublicApiError("not-found", 404);
  if (!response.ok) throw new PublicApiError("server", response.status);
  let envelope: ApiEnvelope<T>;
  try {
    envelope = (await response.json()) as ApiEnvelope<T>;
  } catch {
    throw new PublicApiError("invalid-response", response.status);
  }
  if (!envelope.success || envelope.data === undefined) {
    throw new PublicApiError("invalid-response", response.status);
  }
  return envelope.data;
}

export function listPublicGuidelines(
  filters: PublicGuidelineFilters = {},
  signal?: AbortSignal,
) {
  const query = new URLSearchParams();
  if (filters.search?.trim()) query.set("search", filters.search.trim());
  if (filters.programArea) query.set("program_area", filters.programArea);
  if (filters.country) query.set("country", filters.country);
  if (filters.language) query.set("language", filters.language);
  if (filters.page) query.set("page", String(filters.page));
  if (filters.perPage) query.set("per_page", String(filters.perPage));
  return requestJson<PublicGuidelinePage>(publicUrl("/guidelines", query), signal);
}

export function getPublicGuideline(id: string, signal?: AbortSignal) {
  return requestJson<PublicGuideline>(
    publicUrl(`/guidelines/${encodeURIComponent(id)}`),
    signal,
  );
}

export async function getPublicGuidelineMarkdown(
  id: string,
  signal?: AbortSignal,
): Promise<PublicMarkdown> {
  const cacheKey = id;
  const cached = markdownCache.get(cacheKey);
  const headers: HeadersInit = { Accept: "text/markdown" };
  if (cached?.etag) headers["If-None-Match"] = cached.etag;

  const response = await request(
    publicUrl(`/guidelines/${encodeURIComponent(id)}/markdown`),
    { headers },
    signal,
  );
  if (response.status === 304 && cached) {
    markdownCache.delete(cacheKey);
    markdownCache.set(cacheKey, cached);
    return { ...cached, fromCache: true };
  }
  if (response.status === 404) throw new PublicApiError("not-found", 404);
  if (!response.ok) throw new PublicApiError("server", response.status);

  const result: PublicMarkdown = {
    content: await response.text(),
    etag: response.headers.get("ETag") ?? undefined,
    lastModified: response.headers.get("Last-Modified") ?? undefined,
    fromCache: false,
  };
  markdownCache.set(cacheKey, result);
  while (markdownCache.size > maxCachedDocuments) {
    const oldest = markdownCache.keys().next().value;
    if (oldest === undefined) break;
    markdownCache.delete(oldest);
  }
  return result;
}

export function clearPublicMarkdownCache() {
  markdownCache.clear();
}
