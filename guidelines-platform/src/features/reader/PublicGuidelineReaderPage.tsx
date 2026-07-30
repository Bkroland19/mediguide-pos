import { useEffect, useMemo, useState } from "react";
import { Link, useLocation, useParams } from "react-router-dom";

import {
  getPublicGuideline,
  getPublicGuidelineMarkdown,
  PublicApiError,
  type PublicGuideline,
  type PublicMarkdown,
} from "../../api/public-guidelines";
import { Brand } from "../../components/common/Brand";
import { PageLoading } from "../../components/common/PageLoading";
import { dashboardLoginUrl } from "../../config";
import { getMarkdownHeadings } from "../../lib/markdown/headings";
import { SecureMarkdown } from "./components/SecureMarkdown";

type ReaderState =
  | { status: "loading" }
  | { status: "ready"; guideline: PublicGuideline; markdown: PublicMarkdown }
  | { status: "not-found" }
  | { status: "error" };

export function PublicGuidelineReaderPage() {
  const { guidelineId = "" } = useParams();
  const location = useLocation();
  const [reloadKey, setReloadKey] = useState(0);
  const [state, setState] = useState<ReaderState>({ status: "loading" });

  useEffect(() => {
    const controller = new AbortController();
    Promise.all([
      getPublicGuideline(guidelineId, controller.signal),
      getPublicGuidelineMarkdown(guidelineId, controller.signal),
    ])
      .then(([guideline, markdown]) => setState({ status: "ready", guideline, markdown }))
      .catch((error: unknown) => {
        if (controller.signal.aborted) return;
        if (import.meta.env.DEV) {
          console.warn("Public guideline reader request failed", {
            kind: error instanceof PublicApiError ? error.kind : "unknown",
          });
        }
        setState(
          error instanceof PublicApiError && error.kind === "not-found"
            ? { status: "not-found" }
            : { status: "error" },
        );
      });
    return () => controller.abort();
  }, [guidelineId, reloadKey]);

  useEffect(() => {
    if (state.status !== "ready") return;
    document.title = `${state.guideline.title} | MediGuide`;
    updateMetaDescription(state.guideline.description);
  }, [state]);

  useEffect(() => {
    if (state.status !== "ready" || !location.hash) return;
    const id = decodeURIComponent(location.hash.slice(1));
    const frame = requestAnimationFrame(() => {
      document.getElementById(id)?.scrollIntoView({ block: "start" });
    });
    return () => cancelAnimationFrame(frame);
  }, [location.hash, state]);

  const headings = useMemo(
    () => state.status === "ready" ? getMarkdownHeadings(state.markdown.content) : [],
    [state],
  );

  if (state.status === "loading") {
    return <PageLoading label="Loading published clinical guidance…" />;
  }
  if (state.status === "not-found") {
    return <ReaderMessage title="Guideline not found" message="This guideline is unavailable or has not been published." />;
  }
  if (state.status === "error") {
    return (
      <ReaderMessage title="We could not load this guideline" message="Check your connection and try again.">
        <button className="button button-primary" onClick={() => {
          setState({ status: "loading" });
          setReloadKey((key) => key + 1);
        }}>Try again</button>
      </ReaderMessage>
    );
  }

  const { guideline, markdown } = state;
  return (
    <div className="backend-reader">
      <a className="skip-link" href="#guideline-content">Skip to clinical content</a>
      <header className="backend-reader-header">
        <Link to="/" aria-label="MediGuide guideline library"><Brand /></Link>
        <nav>
          <Link to="/">All guidelines</Link>
          <button type="button" onClick={() => window.print()}>Print</button>
          <a href={dashboardLoginUrl}>Staff login</a>
        </nav>
      </header>
      <div className="backend-reader-grid">
        <aside className="backend-reader-sidebar">
          <Link className="back-link" to="/">← Guideline library</Link>
          <p className="eyebrow">On this page</p>
          {headings.length ? (
            <nav aria-label="Guideline headings">
              {headings.map((heading) => (
                <a className={`toc-depth-${heading.depth}`} href={`#${heading.id}`} key={heading.id}>
                  {heading.text}
                </a>
              ))}
            </nav>
          ) : <p>No section headings</p>}
        </aside>
        <main id="guideline-content" className="backend-reader-main">
          <header className="guideline-metadata">
            <span className="eyebrow">{guideline.program_area || "Published guideline"}</span>
            <h1>{guideline.title}</h1>
            {guideline.description && <p>{guideline.description}</p>}
            <dl>
              <Meta label="Version" value={guideline.version} />
              <Meta label="Source" value={guideline.source_org} />
              <Meta label="Published" value={formatDate(guideline.publication_date)} />
              <Meta label="Review date" value={formatDate(guideline.review_date)} />
              <Meta label="Language" value={guideline.language} />
              <Meta label="Updated" value={formatDate(guideline.last_updated)} />
            </dl>
            {markdown.fromCache && <small>Validated cached copy</small>}
          </header>
          {markdown.content.trim() ? (
            <article className="markdown-content">
              <SecureMarkdown content={markdown.content} />
            </article>
          ) : (
            <div className="library-state">
              <h2>This publication has no readable Markdown content.</h2>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

function Meta({ label, value }: { label: string; value?: string }) {
  if (!value) return null;
  return <div><dt>{label}</dt><dd>{value}</dd></div>;
}

function ReaderMessage({
  title,
  message,
  children,
}: {
  title: string;
  message: string;
  children?: React.ReactNode;
}) {
  return (
    <main className="reader-message">
      <Brand />
      <h1>{title}</h1>
      <p>{message}</p>
      {children}
      <Link to="/">Return to guideline library</Link>
    </main>
  );
}

function formatDate(value?: string) {
  if (!value) return "";
  const parsed = new Date(value);
  return Number.isNaN(parsed.valueOf())
    ? value
    : new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(parsed);
}

function updateMetaDescription(description: string) {
  let element = document.querySelector<HTMLMetaElement>('meta[name="description"]');
  if (!element) {
    element = document.createElement("meta");
    element.name = "description";
    document.head.appendChild(element);
  }
  element.content = description || "Published clinical guidance from MediGuide.";
}
