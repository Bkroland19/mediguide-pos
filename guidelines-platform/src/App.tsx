import { lazy, Suspense } from "react";
import { Navigate, Route, Routes, useParams } from "react-router-dom";

import { PageLoading } from "./components/common/PageLoading";
import { NotFoundPage } from "./features/not-found/NotFoundPage";
import { PublicLayout } from "./layouts/PublicLayout";
import { getPublication } from "./content/publications";

const LandingPage = lazy(() =>
  import("./features/landing/LandingPage").then((module) => ({
    default: module.LandingPage,
  })),
);

const ReaderPage = lazy(() =>
  import("./features/reader/ReaderPage").then((module) => ({
    default: module.ReaderPage,
  })),
);

const PublicGuidelineReaderPage = lazy(() =>
  import("./features/reader/PublicGuidelineReaderPage").then((module) => ({
    default: module.PublicGuidelineReaderPage,
  })),
);

function PublicationRedirect() {
  const { publicationSlug } = useParams();
  const publication = getPublication(publicationSlug);

  return publication ? (
    <Navigate replace to={publication.entryRoute} />
  ) : (
    <NotFoundPage />
  );
}

export default function App() {
  return (
    <Suspense fallback={<PageLoading label="Opening the guidelines…" />}>
      <Routes>
        <Route element={<PublicLayout />}>
          <Route index element={<LandingPage />} />
          <Route
            path="/publications/:publicationSlug"
            element={<PublicationRedirect />}
          />
          <Route path="*" element={<NotFoundPage />} />
        </Route>
        <Route
          path="/publications/:publicationSlug/read/*"
          element={<ReaderPage />}
        />
        <Route
          path="/guidelines/:guidelineId"
          element={<PublicGuidelineReaderPage />}
        />
      </Routes>
    </Suspense>
  );
}
