import type { Metadata } from "next";
import type { CSSProperties } from "react";
import { ThemeProvider } from "@/components/theme-provider";
import { PocketBaseInit } from "@/components/pocketbase-init";
import { Toaster } from "@/components/ui/sonner";
import { QueryProvider } from "@/components/query-provider";
import "./globals.css";

export const metadata: Metadata = {
  title: "MediGuide Dashboard",
  description: "Administrative dashboard for MediGuide health platform",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className="antialiased"
        style={
          {
            "--font-geist-sans": "ui-sans-serif, system-ui, sans-serif",
            "--font-geist-mono": "ui-monospace, SFMono-Regular, monospace",
          } as CSSProperties
        }
      >
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          <QueryProvider>
            <PocketBaseInit />
            {children}
            <Toaster />
          </QueryProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
