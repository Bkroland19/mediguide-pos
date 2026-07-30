import { useMemo, useState } from "react";
import { NavLink } from "react-router-dom";

import { ChevronIcon, SearchIcon } from "../../../components/common/Icons";
import {
  getPublicationDocuments,
  getPublicationNavigation,
} from "../../../content/content-index";
import type { ContentManifestItem, Publication } from "../../../types/content";

export function ReaderSidebar({
  activeItem,
  publication,
  onNavigate,
}: {
  activeItem: ContentManifestItem;
  publication: Publication;
  onNavigate: () => void;
}) {
  const [query, setQuery] = useState("");
  const [expandedChapters, setExpandedChapters] = useState<Set<number>>(
    () => new Set([activeItem.chapter]),
  );
  const normalizedQuery = query.trim().toLowerCase();
  const documents = getPublicationDocuments(publication.id);
  const navigation = getPublicationNavigation(publication.id);

  const searchResults = useMemo(() => {
    if (!normalizedQuery) return [];
    return documents.filter((item) =>
      [
        item.title,
        item.chapterTitle,
        item.sectionNumber,
        `chapter ${item.chapter}`,
      ].some((value) => value?.toLowerCase().includes(normalizedQuery)),
    );
  }, [documents, normalizedQuery]);

  function itemUrl(item: ContentManifestItem) {
    return `/publications/${publication.slug}/read/${item.route}`;
  }

  function toggleChapter(chapter: number) {
    setExpandedChapters((current) => {
      const next = new Set(current);
      if (next.has(chapter)) next.delete(chapter);
      else next.add(chapter);
      return next;
    });
  }

  return (
    <>
      <div className="sidebar-publication">
        <span>Ministry of Health</span>
        <strong>{publication.title}</strong>
        <small>{publication.edition}</small>
      </div>

      <label className="reader-search">
        <span className="visually-hidden">Search publication index</span>
        <SearchIcon />
        <input
          type="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search chapters and topics…"
        />
      </label>

      <nav className="contents-navigation" aria-label="Table of contents">
        {normalizedQuery ? (
          <div className="search-results">
            <span className="results-label">
              {searchResults.length}{" "}
              {searchResults.length === 1 ? "result" : "results"}
            </span>
            {searchResults.slice(0, 60).map((item) => (
              <NavLink key={item.id} to={itemUrl(item)} onClick={onNavigate}>
                <small>
                  {item.chapter === 0
                    ? "Front matter"
                    : `Chapter ${item.chapter} · ${item.sectionNumber}`}
                </small>
                <span>{item.title}</span>
              </NavLink>
            ))}
            {searchResults.length === 0 && (
              <p className="empty-search">
                No sections match “{query.trim()}”.
              </p>
            )}
          </div>
        ) : (
          navigation.map((chapter) => {
            if (chapter.number === 0) {
              const item = chapter.items[0];
              return (
                <NavLink
                  className="front-matter-link"
                  key={item.id}
                  to={itemUrl(item)}
                  onClick={onNavigate}
                >
                  Front matter
                </NavLink>
              );
            }

            const expanded = expandedChapters.has(chapter.number);
            return (
              <div className="chapter-group" key={chapter.number}>
                <button
                  type="button"
                  aria-expanded={expanded}
                  onClick={() => toggleChapter(chapter.number)}
                >
                  <span>
                    <small>Chapter {chapter.number}</small>
                    <strong>{chapter.title}</strong>
                  </span>
                  <ChevronIcon className={expanded ? "is-expanded" : ""} />
                </button>
                {expanded && (
                  <div className="chapter-items">
                    {chapter.items.map((item) => (
                      <NavLink
                        key={item.id}
                        to={itemUrl(item)}
                        onClick={onNavigate}
                      >
                        <small>{item.sectionNumber}</small>
                        <span>{item.title}</span>
                      </NavLink>
                    ))}
                  </div>
                )}
              </div>
            );
          })
        )}
      </nav>

      <div className="reader-sidebar-footer">
        National clinical guidance · {publication.year}
      </div>
    </>
  );
}
