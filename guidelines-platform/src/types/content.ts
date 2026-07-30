export type PublicationStatus = "available" | "coming-soon";

export type Publication = {
  id: string;
  slug: string;
  title: string;
  shortTitle: string;
  description: string;
  publisher: string;
  country: string;
  edition: string;
  year: number;
  chapterCount: number;
  status: PublicationStatus;
  coverTheme: "uganda-green";
  entryRoute: string;
};

export type MarkdownMetadata = {
  title?: string;
  navTitle?: string;
  description?: string;
  order?: number;
  chapterNumber?: number;
  hidden?: boolean;
};

export type ContentManifestItem = {
  id: string;
  publicationId: string;
  sourcePath: string;
  route: string;
  chapter: number;
  chapterTitle: string;
  sectionNumber?: string;
  title: string;
  order: number[];
};

export type MarkdownDocument = ContentManifestItem & {
  content: string;
  metadata: MarkdownMetadata;
};

export type MarkdownHeading = {
  depth: number;
  text: string;
  id: string;
};

export type NavigationChapter = {
  number: number;
  title: string;
  items: ContentManifestItem[];
};
