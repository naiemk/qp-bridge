'use client'
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { AppWrapper } from 'web3-react-ui';
import React, { useState } from "react";
import { GLOBAL_CONFIG } from "@/types/token";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const [error, setError] = useState<Error | null>(null);
  const [k, setKey] = useState<string>('1');
  const [initialized, setInitialized] = useState(false);
  console.log(initialized, 'initialized')

  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        <AppWrapper
          onWeb3OnboardInit={() => setInitialized(true)}
          appMetadata={({
            name: "Demp Bridge",
            icon: "https://ferrum.network/wp-content/uploads/2022/07/cropped-ferrum-favicon-1-32x32.png",
            description: "Demp Bridge",
          })}
          providersConfigUrl="https://raw.githubusercontent.com/naiemk/web3-react-ui-template/refs/heads/main/resources/configs/network-list.json"
          configUrlMaps={{
            "TOKENS": "https://raw.githubusercontent.com/naiemk/web3-react-ui-template/refs/heads/main/resources/configs/tokens.json",
            "APP": "https://raw.githubusercontent.com/naiemk/web3-react-ui-template/refs/heads/main/src/components/example/example-config.json"
          }}
          onError={(error) => setError(error)}
          onConfigLoaded={(k, v) => {
            GLOBAL_CONFIG[k] = v;
            setKey(k); // To refresh the content
          }}
        >
          {error && <div>{error.message}</div>}
          <React.Fragment key={k}>
            {initialized ? children : <div>Initializing...</div>}
          </React.Fragment>
        </AppWrapper>
      </body>
    </html>
  );
}
