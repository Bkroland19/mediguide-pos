export function bookReaderPublicationGuidance(partial: boolean, hasOriginalDocument: boolean) {
  return {
    showOriginal: hasOriginalDocument,
    partialNotice: !partial
      ? undefined
      : hasOriginalDocument
        ? "Some supplemental structured content is unavailable. This published Markdown remains searchable; open the original PDF as the fidelity reference."
        : "Some supplemental structured content is unavailable. This published Markdown contains the reviewed public content currently available.",
  };
}
