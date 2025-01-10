import { useEffect, useState } from "react";
import { ERC20_ABI, Token, useContracts, useErc20 } from "web3-react-ui";
import { ethers } from "ethers";
export const TokenBalance = ({token, userAddress}: {token: Token, userAddress: string}) => {
  const { toHumanReadable, tokenData, getBalance } = useErc20(token.address, token.chainId);
  const [balance, setBalance] = useState<string | null>(null);
  const { callMethod, error } = useContracts();
  console.log('TokenBalance', token, userAddress, tokenData)
  useEffect(() => {
    if (tokenData && userAddress) {
      const _getBalance = async () => {
        try {
          console.log('Getting balance', token.chainId, token.address, userAddress, token.isNative)
          const balanceRaw = await getBalance(userAddress);
          console.log('Balance raw', balanceRaw)
          setBalance(toHumanReadable(balanceRaw || '0'))
        } catch (e) {
          console.error('Error getting balance', e)
        }
      }
      _getBalance()
    }
  }, [tokenData, userAddress, token, callMethod, toHumanReadable]);

  return (
    <div className="text-sm text-muted-foreground px-2">
      Balance: {balance} {token.symbol} {error}
    </div>
  )
}
