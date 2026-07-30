import { Link } from "react-router-dom";

export function Brand() {
  return (
    <Link className="brand" to="/" aria-label="Clinical Guidelines home">
      <span className="brand-mark" aria-hidden="true">
        +
      </span>
      <span>
        <strong>Clinical Guidelines</strong>
        <small>MediGuide</small>
      </span>
    </Link>
  );
}
