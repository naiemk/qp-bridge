
export interface Dependencies {
  bridge?: string;
  portal: string;
  remotePeers: {
    [chainId: string]: string;
  }
  remotePairs: {
    [chainId: string]: {
      [token: string]: string;
    }
  }
}

export const DEPENDENCIES_ARBITRUM: Dependencies = {
  bridge: "0x7d1993493fe25026B1C9C7Aa22772612c070B500",
  portal: "0xa45baceeb0c6b072b17ef6483e4fb50a49dc5f4b",
  remotePeers: {
    "26100": "0x7d1993493fe25026B1C9C7Aa22772612c070B500",
  },
  remotePairs: {
    "26100": {
      "0x9f6abbf0ba6b5bfa27f4deb6597cc6ec20573fda": "0x0000000000000000000000000000000000000001",
    },
  }
}

export const DEPENDENCIES_FERRUM: Dependencies = {
  bridge: "0x7d1993493fe25026B1C9C7Aa22772612c070B500",
  portal: "0xa45baceeb0c6b072b17ef6483e4fb50a49dc5f4b",
  remotePeers: {
    "42161": "0x7d1993493fe25026B1C9C7Aa22772612c070B500",
  },
  remotePairs: {
    "42161": {
      "0x0000000000000000000000000000000000000001": "0x9f6abbf0ba6b5bfa27f4deb6597cc6ec20573fda",
    },
  }
}

export const CONFIG: { [chainId: string]: Dependencies } = {
  "42161": DEPENDENCIES_ARBITRUM,
  "26100": DEPENDENCIES_FERRUM,
}

export const panick = (msg: string) => { throw new Error(msg) }

/*
26100

DeployModule#bridge_impl_01 - 0x7b3B0A3cCd940c27C12c1487054348EB531847ea
DeployModule#bridge_proxy_01 - 0x7d1993493fe25026B1C9C7Aa22772612c070B500
DeployModule#bridge_01 - 0x7d1993493fe25026B1C9C7Aa22772612c070B500

DeployModule#bridge_impl_01 - 0x7b3B0A3cCd940c27C12c1487054348EB531847ea
DeployModule#bridge_proxy_01 - 0x7d1993493fe25026B1C9C7Aa22772612c070B500
DeployModule#bridge_01 - 0x7d1993493fe25026B1C9C7Aa22772612c070B500


*/