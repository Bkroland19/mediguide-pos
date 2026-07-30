declare global {
  interface Window {
    __APP_CONFIG__?: {
      mediguidePosUrl?: string;
    };
  }
}

const defaultMediguidePosUrl = "http://localhost:3000";

function normalizeBaseUrl(value: string | undefined) {
  return (value?.trim() || defaultMediguidePosUrl).replace(/\/+$/, "");
}

const mediguidePosUrl = normalizeBaseUrl(
  window.__APP_CONFIG__?.mediguidePosUrl ||
    import.meta.env.VITE_MEDIGUIDE_POS_URL,
);

export const dashboardBaseUrl = mediguidePosUrl;
export const dashboardLoginUrl = `${dashboardBaseUrl}/login`;
export const mediguidePosLoginUrl = dashboardLoginUrl;
