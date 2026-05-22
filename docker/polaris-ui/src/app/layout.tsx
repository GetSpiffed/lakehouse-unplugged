import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Polaris Read-Only UI',
  description: 'Read-only inspector for Apache Polaris configuration'
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
