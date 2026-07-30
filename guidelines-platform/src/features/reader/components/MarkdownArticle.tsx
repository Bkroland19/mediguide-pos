import { useEffect } from "react";
import { useLocation } from "react-router-dom";
import { resolveMarkdownAsset } from "../../../content/content-loader";
import type { MarkdownDocument } from "../../../types/content";
import { SecureMarkdown } from "./SecureMarkdown";

export function MarkdownArticle({
  document: markdownDocument,
}: {
  document: MarkdownDocument;
}) {
  const location = useLocation();

  useEffect(() => {
    window.document.title = `${markdownDocument.title} | Uganda Clinical Guidelines`;
  }, [markdownDocument.title]);

  useEffect(() => {
    if (!location.hash) {
      window.scrollTo({ top: 0, left: 0, behavior: "instant" });
      return;
    }

    const headingId = decodeURIComponent(location.hash.slice(1));
    const frame = requestAnimationFrame(() => {
      window.document
        .getElementById(headingId)
        ?.scrollIntoView({ behavior: "smooth", block: "start" });
    });

    return () => cancelAnimationFrame(frame);
  }, [markdownDocument.id, location.hash]);

  return (
    <article className="markdown-content">
      <div className="document-context">
        {markdownDocument.chapter > 0 ? (
          <>
            <span>Chapter {markdownDocument.chapter}</span>
            <span>{markdownDocument.chapterTitle}</span>
          </>
        ) : (
          <span>Uganda Clinical Guidelines</span>
        )}
      </div>
      <SecureMarkdown
        content={markdownDocument.content}
        resolveImage={(source) => resolveMarkdownAsset(markdownDocument, source)}
      />
    </article>
  );
}
