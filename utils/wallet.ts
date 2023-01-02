import { BigNumber, Wallet } from 'ethers';
import { getAddress } from 'ethers/lib/utils';
import { ethers, network } from 'hardhat';
import { randomHex } from 'web3-utils';
import { JsonRpcSigner } from '@ethersproject/providers';

export const impersonate = async (address: string): Promise<JsonRpcSigner> => {
  await network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [address],
  });
  await fund(address, ethers.BigNumber.from('100000000000000000000000'))
  return ethers.provider.getSigner(address) as JsonRpcSigner;
};

export const fund = async (address: string, amount: BigNumber) =>{
  await network.provider.send('hardhat_setBalance', [address, (amount.toHexString()).replace('0x0','0x')]);
}

export const generateRandom = async () => {
  return (Wallet.createRandom()).connect(ethers.provider);
};

export const generateRandomWithEth = async (amount: BigNumber) => {
  const [governance] = await ethers.getSigners();
  const wallet = await generateRandom();
  await governance.sendTransaction({ to: wallet.address, value: amount });
  return wallet;
};

export const generateRandomAddress = () => {
  return getAddress(randomHex(20));
};
