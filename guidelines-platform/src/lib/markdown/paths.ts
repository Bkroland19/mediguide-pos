const protocolPattern = /^(?:[a-z]+:|\/|#)/i;

export function normalizeRelativePath(path: string): string {
  const segments: string[] = [];

  for (const segment of path.split("/")) {
    if (!segment || segment === ".") continue;
    if (segment === "..") {
      if (segments.length > 0 && segments.at(-1) !== "..") segments.pop();
      else segments.push(segment);
    } else {
      segments.push(segment);
    }
  }

  return segments.join("/");
}

export function resolveRelativeAssetPath(
  documentSourcePath: string,
  assetSource: string | undefined,
) {
  if (!assetSource || protocolPattern.test(assetSource)) return assetSource;

  const normalizedAssetSource = assetSource.replace(
    /(^|\/)UCG2023_images\//,
    "$1images/",
  );
  const sourceDirectory = documentSourcePath.slice(
    0,
    documentSourcePath.lastIndexOf("/"),
  );

  return normalizeRelativePath(`${sourceDirectory}/${normalizedAssetSource}`);
}

export function normalizeContentRoute(route: string) {
  return decodeURIComponent(route).replace(/^\/+|\/+$/g, "");
}
