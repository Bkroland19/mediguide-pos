import type { PublicGuidelineSection } from "../../../api/public-guidelines";

export function EmptyReviewedSection({
  hasOriginalDocument,
  descendants,
  onSection,
  onOpenOriginal,
}: {
  hasOriginalDocument: boolean;
  descendants: PublicGuidelineSection[];
  onSection: (id: string) => void;
  onOpenOriginal: () => void;
}) {
  if (descendants.length > 0) {
    return <div className="library-state">
      <h2>Reviewed content in this chapter</h2>
      <p>This is a container section. Continue to a reviewed subsection.</p>
      {descendants.map((section) => <button className="button button-outline" key={section.id} onClick={() => onSection(section.id)}>{section.title}</button>)}
    </div>;
  }
  if (hasOriginalDocument) {
    return <div className="library-state">
      <h2>0 reviewed blocks</h2>
      <p>No approved structured content is available for this section.</p>
      <button className="button button-outline" onClick={onOpenOriginal}>Open original document</button>
    </div>;
  }
  return <div className="library-state">
    <h2>0 reviewed blocks</h2>
    <p>This section has not yet been published as reviewed content.</p>
  </div>;
}
