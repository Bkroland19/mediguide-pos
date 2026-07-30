import { Link } from "react-router-dom";

export function NotFoundPage() {
  return (
    <section className="not-found page-shell">
      <span className="eyebrow">404 · Page not found</span>
      <h1>We could not find that guideline page.</h1>
      <p>
        The address may be outdated, or the requested clinical document may no
        longer be available at this location.
      </p>
      <Link className="button button-primary" to="/">
        Return to the guideline library
      </Link>
    </section>
  );
}
