'use client'

import { Button } from "@/components/ui/button"
import { Sun, Moon } from 'lucide-react'
import { useTheme } from './theme-provider'
import Web3Connect from '@/components/web3/web3-connect'
import Image from 'next/image'
import frmLogo from '@/img/ferrum-network-logo.png'

export function Navbar() {
  const { theme, toggleTheme } = useTheme()

  return (
    <nav className="h-16 flex justify-between items-center px-4 sm:px-6 border-b bg-background/80 backdrop-blur-sm fixed top-0 left-0 right-0 z-50">
      <div className="text-2xl font-bold text-foreground">
        <Image src={frmLogo.src} alt="Quantum Portal Bridge" width={250} height={100} />
        {/* <span className="text-2xl font-bold text-foreground">Quantum Portal Bridge</span> */}
      </div>
      <div className="flex items-center space-x-4">
        <Web3Connect />
        <Button variant="ghost" size="icon" onClick={toggleTheme} className="text-foreground">
          {theme === 'dark' ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
        </Button>
      </div>
    </nav>
  )
}

