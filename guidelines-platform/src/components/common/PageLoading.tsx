export function PageLoading({ label = "Loading…" }: { label?: string }) {
  return (
    <div className="page-loading" role="status">
      <span className="loading-mark" aria-hidden="true" />
      <span>{label}</span>
    </div>
  );
}
