import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";

import { PageLoading } from "../../components/common/PageLoading";
import { getContentByRoute } from "../../content/content-index";
import { loadMarkdownDocument } from "../../content/content-loader";
import { getPublication } from "../../content/publications";
import type { MarkdownDocument } from "../../types/content";
import { NotFoundPage } from "../not-found/NotFoundPage";
import { MarkdownArticle } from "./components/MarkdownArticle";
import { ReaderLayout } from "./components/ReaderLayout";

type LoadState =
  | { status: "loading" }
  | { status: "ready"; document: MarkdownDocument }
  | { status: "error" };

export function ReaderPage() {
  const params = useParams();
  const publication = getPublication(params.publicationSlug);
  const item = publication
    ? getContentByRoute(publication.id, params["*"])
    : undefined;

  if (!publication || !item) {
    return <NotFoundPage />;
  }

  return (
    <DocumentReader key={item.id} item={item} publication={publication} />
  );
}

function DocumentReader({
  item,
  publication,
}: {
  item: NonNullable<ReturnType<typeof getContentByRoute>>;
  publication: NonNullable<ReturnType<typeof getPublication>>;
}) {
  const [loadState, setLoadState] = useState<LoadState>({ status: "loading" });

  useEffect(() => {
    let cancelled = false;
    loadMarkdownDocument(item)
      .then((document) => {
        if (!cancelled) setLoadState({ status: "ready", document });
      })
      .catch(() => {
        if (!cancelled) setLoadState({ status: "error" });
      });

    return () => {
      cancelled = true;
    };
  }, [item]);

  if (loadState.status === "error") {
    return <NotFoundPage />;
  }

  return (
    <ReaderLayout activeItem={item} publication={publication}>
      {loadState.status === "loading" ? (
        <PageLoading label="Loading clinical guidance…" />
      ) : (
        <MarkdownArticle document={loadState.document} />
      )}
    </ReaderLayout>
  );
}
