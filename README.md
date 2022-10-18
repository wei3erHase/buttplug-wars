# ButtPlug Wars

#### ButtPlugWars is a FiveOutOfNine wrapper to play team-up one-vs-one a-la-0xMonaco style, playing in turns vs the chess engine.

The objective is to eat more pieces, and be eaten as less as possible, while playing against the board. By checkmate, team with higher score wins a match, 9 matches to play, first to 5 wins the game.

Since processing the chess engine can be gas consuming, and the board is on mainnet, the game is going to rely on keepers to execute the transactions, and will use the badge sales ETH to generate a liquidity, whose yield is going to reward keepers for the on-chain processing of the board-engine. By using the Keep3r Network, keepers are going to spend their ETH transacting the moves, while receiving yield-generated-KP3R rewards for it.

By the end of the game, all liquidity is withdrawn, and winner team players can claim their share of it. Players from the team who didn't win, or those who didn't claim their prize, can claim a share of the sales of the minted 5/9 NFTs. Each one, will be deposited into a Sudoswap sale position. And keepers are required, at each game, to hold a balance of 5/9 NFT equal to the match number (from 1 to 9).

Badge minting requires bonding a 5/9 NFT, and depositing an amount of ETH between 0.05 and 1. Burning will only be allowed after game ends, to claim the prize (depositing the 5/9 in the pool), or to withdraw the bonded 5/9 (claiming sales so far). The weight of the deposited ETH will vary with game rounds, starting at a `x2` multiplier, and having a `x1` at match n9.

> ETH will be traded for KP3R and bonded as a full-range liquidity (kLP), so value of all the inputed ETH, and all withdrawn kLP as prize may vary with time.

The more players, the higher liquidity, the faster KP3R credits are minted, the higher the frequency with wich a the next move can be run, and give the reward to the keeper. The depth with which the move will be played (defining how smart the engine will play), will be pseudo-randomly defined by the board state and the keeper address, shuffling every 30m window.

The teams need to deploy and vote an address, that should provide a `readMove(uint board) view returns (uint move)` method, being penalized with `-1` point should the read or the move revert. Team turns will be defined by periods of 5 days. When a transaction reverts, next team will play, when their turn comes, having acumulated credits to have more gameplay.
