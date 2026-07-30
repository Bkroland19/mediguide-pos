import { useEffect } from "react";
import { useLocation } from "react-router-dom";
import ReactMarkdown from "react-markdown";
import rehypeAutolinkHeadings from "rehype-autolink-headings";
import rehypeRaw from "rehype-raw";
import rehypeSlug from "rehype-slug";
import remarkGfm from "remark-gfm";

import { resolveMarkdownAsset } from "../../../content/content-loader";
import type { MarkdownDocument } from "../../../types/content";

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
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        rehypePlugins={[
          rehypeRaw,
          rehypeSlug,
          [rehypeAutolinkHeadings, { behavior: "wrap" }],
        ]}
        components={{
          a: ({ href, children, ...properties }) => {
            const external = /^https?:\/\//.test(href ?? "");
            return (
              <a
                href={href}
                {...properties}
                target={external ? "_blank" : undefined}
                rel={external ? "noreferrer noopener" : undefined}
              >
                {children}
              </a>
            );
          },
          img: ({ src, alt, ...properties }) => (
            <img
              src={resolveMarkdownAsset(markdownDocument, src)}
              alt={alt ?? ""}
              loading="lazy"
              {...properties}
            />
          ),
        }}
      >
        {markdownDocument.content}
      </ReactMarkdown>
    </article>
  );
}
