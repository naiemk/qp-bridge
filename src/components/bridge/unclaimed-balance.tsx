import { AlertCircle } from "lucide-react";
import { Alert, AlertDescription } from "../ui/alert";
import { getChain, useConnectWalletSimple, useContracts } from "web3-react-ui";
import { useEffect, useState } from "react";
import { UnclaimedBalanceModal } from "./unclaimed-balance-modal";

export function UnclaimedBalance({contractAddress}: {contractAddress: string}) {
  const { address, chainId} = useConnectWalletSimple();
  const [isUnclaimedBalanceModalOpen, setIsUnclaimedBalanceModalOpen] = useState(false)
  const [unclaimedBalance, setUnclaimedBalance] = useState({
    amount: '',
    token: null
  })
  const { callMethod, execute } = useContracts();

  useEffect(() => {
    const getUnclaimedBalance = async () => {
      if (address && chainId) {
        const balanceLen = await callMethod('qp-bridge', 'pendingSwapsLength',
          'function pendingSwapsLength(address user) returns (uint256)', [address])
        if (!balanceLen || balanceLen == BigInt(0)) {
          setUnclaimedBalance({
            amount: '0',
            token: null
          })
          return;
        }
        const topBalance = await callMethod('qp-bridge', 'pendingSwaps',
          'function pendingSwaps(address user, uint256 index) returns (address token, uint256 amount, address recipient)',
          [address, balanceLen - BigInt(1)])
        if (topBalance) {
          const balance = {
            tokenAddress: topBalance[0].toString(),
            amount: topBalance[1].toString(),
          }
          setUnclaimedBalance(balance as any)
        }
      }
    }
    getUnclaimedBalance()
  }, [address, chainId])

  const handleClaim = async () => {
    console.log('Claiming balance')
    setIsUnclaimedBalanceModalOpen(false)
    const tx = await execute(contractAddress, 'function withdrawAllPendingSwaps(address user)', [address]);
    console.log('Claim transaction:', tx);
  }

  if (!unclaimedBalance.amount || unclaimedBalance.amount === '0') {
    return <></>
  }

  return (
    <>
      <Alert>
        <AlertCircle className="h-4 w-4" />
        <AlertDescription>
          You have some unclaimed balance on the {getChain(chainId || '1')?.label}.{' '}
          <button
            onClick={() => setIsUnclaimedBalanceModalOpen(true)}
            className="font-medium underline underline-offset-4"
          >
            See more
          </button>
        </AlertDescription>
      </Alert>
      <UnclaimedBalanceModal
        isOpen={isUnclaimedBalanceModalOpen}
        onClose={() => setIsUnclaimedBalanceModalOpen(false)}
        chainId={chainId!}
        unclaimedBalance={unclaimedBalance}
        onClaim={() => {
          handleClaim()
        }}
      />
    </>
  )
}