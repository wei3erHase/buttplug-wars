import { BigNumber, utils } from 'ethers';

export const toBN = (value: string | number | BigNumber): BigNumber => {
  return BigNumber.isBigNumber(value) ? value : BigNumber.from(value);
};

export const toUnit = (value: number): BigNumber => {
  return utils.parseUnits(value.toString());
};

export const toGwei = (value: number): BigNumber => {
  return utils.parseUnits(value.toString(), 'gwei');
};
