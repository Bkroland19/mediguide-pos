import type { PublicGuidelineBlock, PublicGuidelineSection } from "../../../api/public-guidelines";

export function reviewedDescendants(
  sectionId: string,
  sections: PublicGuidelineSection[],
  blocks: PublicGuidelineBlock[],
) {
  const children = new Map<string, PublicGuidelineSection[]>();
  for (const section of sections) {
    if (!section.parent_id) continue;
    children.set(section.parent_id, [...(children.get(section.parent_id) ?? []), section]);
  }
  const reviewedSectionIds = new Set(blocks.map((block) => block.section_id).filter((id): id is string => Boolean(id)));
  const queue = [...(children.get(sectionId) ?? [])];
  const descendants: PublicGuidelineSection[] = [];
  while (queue.length) {
    const section = queue.shift()!;
    if (reviewedSectionIds.has(section.id)) descendants.push(section);
    queue.push(...(children.get(section.id) ?? []));
  }
  return descendants.slice(0, 12);
}
