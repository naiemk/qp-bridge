import { useEffect, useState } from "react";
import { ERC20_ABI, Token, useContracts, useErc20 } from "web3-react-ui";

export const TokenBalance = ({token, userAddress}: {token: Token, userAddress: string}) => {
  const { toHumanReadable, tokenData } = useErc20(token.address, token.chainId);
  const [balance, setBalance] = useState<string | null>(null);
  const { callMethod, error } = useContracts();
  useEffect(() => {
    if (tokenData && userAddress) {
      console.log('Getting balance')
      const getBalance = async () => {
        const balance = await callMethod(token.chainId, token.address, ERC20_ABI.BALANCE_OF, [userAddress])
        setBalance(toHumanReadable(balance || '0'))
      }
      getBalance()
    }
  }, [tokenData, userAddress, token, callMethod, toHumanReadable]);

  return (
    <div className="text-sm text-muted-foreground px-2">
      Balance: {balance} {token.symbol} {error}
    </div>
  )
}
