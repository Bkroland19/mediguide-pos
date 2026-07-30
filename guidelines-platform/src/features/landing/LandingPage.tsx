import { useEffect } from "react";
import { Link } from "react-router-dom";

import {
  ArrowIcon,
  BookIcon,
  ShieldIcon,
} from "../../components/common/Icons";
import { dashboardLoginUrl } from "../../config";
import { publications } from "../../content/publications";

export function LandingPage() {
  useEffect(() => {
    document.title = "MediGuide Clinical Guidelines";
  }, []);

  return (
    <>
      <section className="landing-hero">
        <div className="page-shell hero-grid">
          <div className="hero-copy">
            <span className="eyebrow">
              Republic of Uganda · Ministry of Health
            </span>
            <h1>
              Clinical guidance,
              <span> ready when care decisions matter.</span>
            </h1>
            <p>
              Browse Uganda&apos;s national clinical publications in a clear,
              searchable format designed for health workers at every level of
              care.
            </p>
            <div className="hero-actions">
              <a className="button button-primary" href="#guidelines">
                Browse guidelines <ArrowIcon />
              </a>
              <a className="button button-quiet" href={dashboardLoginUrl}>
                Open staff dashboard
              </a>
            </div>
            <div className="trust-line">
              <ShieldIcon />
              <span>Official national clinical guidance · 2023 edition</span>
            </div>
          </div>

          <div className="hero-publication" aria-hidden="true">
            <div className="hero-book">
              <span>Republic of Uganda</span>
              <div>
                <small>Ministry of Health</small>
                <strong>Uganda Clinical Guidelines</strong>
                <em>National guidance for common health conditions</em>
              </div>
              <b>2023</b>
            </div>
            <div className="hero-book-shadow" />
          </div>
        </div>
      </section>

      <section className="library-section page-shell" id="guidelines">
        <div className="section-intro">
          <div>
            <span className="eyebrow">Clinical library</span>
            <h2>Available publications</h2>
          </div>
          <p>
            Select a publication to browse its chapters and clinical sections.
          </p>
        </div>

        <div className="publication-grid">
          {publications.map((publication) => (
            <Link
              className="publication-card"
              to={publication.entryRoute}
              key={publication.id}
            >
              <div className="publication-cover">
                <span>{publication.country}</span>
                <strong>{publication.shortTitle}</strong>
                <small>{publication.year}</small>
              </div>
              <div className="publication-card-content">
                <span className="publication-publisher">
                  {publication.publisher}
                </span>
                <h3>{publication.title}</h3>
                <p>{publication.description}</p>
                <dl className="publication-meta">
                  <div>
                    <dt>Edition</dt>
                    <dd>{publication.edition}</dd>
                  </div>
                  <div>
                    <dt>Coverage</dt>
                    <dd>{publication.chapterCount} chapters</dd>
                  </div>
                </dl>
                <span className="card-action">
                  Open publication <ArrowIcon />
                </span>
              </div>
            </Link>
          ))}
        </div>
      </section>

      <section className="about-section" id="about">
        <div className="page-shell about-grid">
          <div>
            <span className="eyebrow">Built for practical use</span>
            <h2>National guidance in a format that is easier to navigate.</h2>
          </div>
          <div className="about-points">
            <article>
              <BookIcon />
              <div>
                <h3>Structured by chapter</h3>
                <p>
                  Move directly between clinical topics without searching
                  through one long document.
                </p>
              </div>
            </article>
            <article>
              <SearchIcon />
              <div>
                <h3>Find sections quickly</h3>
                <p>
                  Search the publication index by chapter, section number, or
                  topic title.
                </p>
              </div>
            </article>
          </div>
        </div>
      </section>
    </>
  );
}

function SearchIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
    >
      <circle cx="11" cy="11" r="6" />
      <path d="m16 16 4 4" />
    </svg>
  );
}
