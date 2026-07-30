import { useState, type PropsWithChildren } from "react";
import { Link } from "react-router-dom";

import { Brand } from "../../../components/common/Brand";
import {
  ArrowIcon,
  CloseIcon,
  MenuIcon,
} from "../../../components/common/Icons";
import { dashboardLoginUrl } from "../../../config";
import { getAdjacentDocuments } from "../../../content/content-index";
import type { ContentManifestItem, Publication } from "../../../types/content";
import { ReaderSidebar } from "./ReaderSidebar";

type ReaderLayoutProps = PropsWithChildren<{
  activeItem: ContentManifestItem;
  publication: Publication;
}>;

function readerUrl(publication: Publication, item: ContentManifestItem) {
  return `/publications/${publication.slug}/read/${item.route}`;
}

export function ReaderLayout({
  activeItem,
  publication,
  children,
}: ReaderLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { previous, next } = getAdjacentDocuments(activeItem);

  return (
    <div className="reader-site">
      <a className="skip-link" href="#reader-content">
        Skip to clinical content
      </a>
      <header className="reader-header">
        <button
          className="icon-button reader-menu-button"
          type="button"
          aria-label="Open table of contents"
          onClick={() => setSidebarOpen(true)}
        >
          <MenuIcon />
        </button>
        <Link className="reader-title" to={publication.entryRoute}>
          <span>{publication.shortTitle}</span>
          <strong>{publication.title}</strong>
        </Link>
        <div className="reader-actions">
          <Link to="/">All guidelines</Link>
          <a className="button button-small button-primary" href={dashboardLoginUrl}>
            Staff login
          </a>
        </div>
      </header>

      <aside
        className={`reader-sidebar ${sidebarOpen ? "is-open" : ""}`}
        aria-label="Publication contents"
      >
        <div className="reader-sidebar-brand">
          <Brand />
          <button
            className="icon-button sidebar-close"
            type="button"
            aria-label="Close table of contents"
            onClick={() => setSidebarOpen(false)}
          >
            <CloseIcon />
          </button>
        </div>
        <ReaderSidebar
          activeItem={activeItem}
          publication={publication}
          onNavigate={() => setSidebarOpen(false)}
        />
      </aside>

      {sidebarOpen && (
        <button
          className="reader-scrim"
          type="button"
          aria-label="Close table of contents"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      <main className="reader-main" id="reader-content">
        <div className="reader-column">
          {children}
          <nav className="document-pagination" aria-label="Document pagination">
            {previous ? (
              <Link to={readerUrl(publication, previous)}>
                <ArrowIcon className="arrow-back" />
                <span>
                  <small>Previous</small>
                  <strong>{previous.title}</strong>
                </span>
              </Link>
            ) : (
              <span />
            )}
            {next && (
              <Link to={readerUrl(publication, next)}>
                <span>
                  <small>Next</small>
                  <strong>{next.title}</strong>
                </span>
                <ArrowIcon />
              </Link>
            )}
          </nav>
        </div>
      </main>
    </div>
  );
}
