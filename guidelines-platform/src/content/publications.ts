import type { Publication } from "../types/content";

export const publications: Publication[] = [
  {
    id: "uganda-clinical-guidelines",
    slug: "uganda-clinical-guidelines",
    title: "Uganda Clinical Guidelines",
    shortTitle: "UCG",
    description:
      "National guidance for diagnosing and managing common health conditions across every level of care.",
    publisher: "Republic of Uganda · Ministry of Health",
    country: "Uganda",
    edition: "2023 edition",
    year: 2023,
    chapterCount: 24,
    status: "available",
    coverTheme: "uganda-green",
    entryRoute:
      "/publications/uganda-clinical-guidelines/read/front-matter",
  },
];

export function getPublication(slug: string | undefined) {
  return publications.find((publication) => publication.slug === slug);
}
