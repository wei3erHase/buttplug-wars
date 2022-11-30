import { Contract, ContractFactory, ContractInterface } from '@ethersproject/contracts';
import { TransactionResponse, TransactionReceipt } from '@ethersproject/abstract-provider';
import { Signer } from 'ethers';
import { getStatic } from 'ethers/lib/utils';
import { ethers } from 'hardhat';
import path from 'path';
import fs from 'fs';

export const deploy = async(signer: Signer, path: string, args: any[]): Promise<Contract> => {
  const artifact = fs.readFileSync(path)
  const parsedArtifact = JSON.parse(artifact.toString());
  const contractFactory = await ethers.getContractFactory(parsedArtifact.abi, parsedArtifact.bytecode.object, signer)
  const contract: Contract = await contractFactory.deploy(...args)
  return contract
};

export const getContractInterface = async(path: string): Promise<ContractInterface> => {
  const artifact = fs.readFileSync(path)
  const parsedArtifact = JSON.parse(artifact.toString());
  const contractFactory: ContractFactory = await ethers.getContractFactory(parsedArtifact.abi, parsedArtifact.bytecode.object)
  const contractInterface = contractFactory.interface;
  return contractInterface
};

export const getContractAbi = async(path: string): Promise<ContractInterface> => {
  const artifact = fs.readFileSync(path)
  const parsedArtifact = JSON.parse(artifact.toString());
  return parsedArtifact.abi
};

export const getContractFactory = async(path: string): Promise<{ contractFactory: ContractFactory }> => {
  const artifact = fs.readFileSync(path)
  const parsedArtifact = JSON.parse(artifact.toString());
  const contractFactory: ContractFactory = await ethers.getContractFactory(parsedArtifact.abi, parsedArtifact.bytecode.object)
  return {contractFactory}
};

export const deployTx = async (contract: ContractFactory, args: any[]): Promise<{ tx: TransactionResponse; contract: Contract }> => {
  const deploymentTransactionRequest = await contract.getDeployTransaction(...args);
  const deploymentTx = await contract.signer.sendTransaction(deploymentTransactionRequest);
  const contractAddress = getStatic<(deploymentTx: TransactionResponse) => string>(contract.constructor, 'getContractAddress')(deploymentTx);
  const deployedContract = getStatic<(contractAddress: string, contractInterface: ContractInterface, signer?: Signer) => Contract>(
    contract.constructor,
    'getContract'
  )(contractAddress, contract.interface, contract.signer);
  return {
    tx: deploymentTx,
    contract: deployedContract,
  };
};

export const logTx = async (tx: TransactionResponse): Promise<number> => {
const receipt = await tx.wait()
const gasUsed = receipt.gasUsed
console.log('gasUsed', gasUsed.toString())
return gasUsed.toNumber()
}
