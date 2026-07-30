import { useState, type ComponentProps } from "react";
import ReactMarkdown from "react-markdown";
import rehypeAutolinkHeadings from "rehype-autolink-headings";
import rehypeSlug from "rehype-slug";
import remarkGfm from "remark-gfm";

type SecureMarkdownProps = {
  content: string;
  resolveImage?: (source: string | undefined) => string | undefined;
};

function isExternalUrl(value: string | undefined) {
  return /^https?:\/\//i.test(value ?? "");
}

function safeImageSource(value: string | undefined) {
  if (!value) return undefined;
  if (/^(https?:\/\/|\/(?!\/)|\.{0,2}\/)/i.test(value)) return value;
  return undefined;
}

export function SecureMarkdown({ content, resolveImage }: SecureMarkdownProps) {
  return (
    <ReactMarkdown
      remarkPlugins={[remarkGfm]}
      rehypePlugins={[
        rehypeSlug,
        [rehypeAutolinkHeadings, { behavior: "wrap" }],
      ]}
      components={{
        a: ({ href, children, ...properties }) => (
          <a
            href={href}
            {...properties}
            target={isExternalUrl(href) ? "_blank" : undefined}
            rel={isExternalUrl(href) ? "noopener noreferrer" : undefined}
          >
            {children}
          </a>
        ),
        img: (properties: ComponentProps<"img">) => (
          <SafeMarkdownImage {...properties} resolveImage={resolveImage} />
        ),
      }}
    >
      {content}
    </ReactMarkdown>
  );
}

function SafeMarkdownImage({
  src,
  alt,
  resolveImage,
  ...properties
}: ComponentProps<"img"> & {
  resolveImage?: (source: string | undefined) => string | undefined;
}) {
  const [failed, setFailed] = useState(false);
  const resolved = safeImageSource(resolveImage ? resolveImage(src) : src);
  if (!resolved || failed) {
    return <span className="broken-markdown-image">Image unavailable: {alt}</span>;
  }
  return (
    <img
      src={resolved}
      alt={alt ?? ""}
      loading="lazy"
      {...properties}
      onError={() => setFailed(true)}
    />
  );
}
