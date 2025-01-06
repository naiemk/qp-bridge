import { Layout } from '@/components/bridge/layout'
import { TokenEditorSection } from '@/components/bridge/token-editor-section'
import frmLogo from '@/img/ferrum-network-logo.png'
import Image from 'next/image'

export default function Home() {
  return (
    <Layout>
      <div className="min-h-[calc(100vh-64px)] flex flex-col items-center justify-center p-4">
        <h4 className="text-3xl font-bold mb-8 text-foreground">Quantum Portal Bridge</h4>
        <TokenEditorSection />
      </div>
    </Layout>
  );
}
