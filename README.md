# ButtPlugWars

Welcome to the first decentralized Chess Olympiads (aka ButtPlugWars).

#### A FiveOutOfNine wrapper to play team-up one-vs-one a-la-0xMonaco style, playing in turns vs the chess engine.

This game is a chess tournament in which teams compete against an automated on-chain chessboard. The objective is to capture as many pieces as possible while minimizing the loss of your own pieces. The team with the highest score at the end of a match, which consists of nine rounds, wins. The first team to win five matches is declared the overall winner.

To facilitate the execution of chess moves on the Ethereum mainnet, the game relies on "keepers" to process transactions. These keepers are rewarded with KP3R tokens, generated from the ETH that players bond to play. The game utilizes the Keep3r Network to manage this process.

To participate in the game, players must bond a 5/9 NFT and deposit a certain amount of ETH, between 0.05 and 1. At the end of the game, all liquidity is withdrawn and distributed to players of the winner team, and sales of the 5/9 tokens are distributed to all participants, depending on their individual score.

By using a Sudoswap pool with a XYK curve, the game can limit the minting of NFTs, making it dependant on the demand. Overall, it helps to manage the minting of NFTs in a way that promotes stability and fairness within the game.

### Curatotial note

In this exciting event, two teams will go head to head in a tournament style chess competition against an automated chessboard that always plays as the black pieces.

This provocative project delves into the murky world of chess cheating and the depths some players will go to in order to win.

Developers are invited to test their own chess skills challenging a very basic AI to a game. The question is posed: would you be able to detect and outsmart a cheat in the midst of a high-stakes game?

Will your team rise to the top and outsmart the automated chessboard, or will the machine prove to be too formidable a foe? Come and find out at the Olympiads.

### How it's played

To start the game, players are divided into teams. Each team will then take turns of 5 days playing against the chess board. The movements are made by proposing a strategy and having their teammates vote on it. The strategy with the most votes from each team will be the one that gets executed.

### Objective

The rules are simple: teams will take turns facing off in a series of matches, with the first team to win 5 matches declared the winner.

Each time a black piece is captured by a team, they score 2 points (despite which piece it is). However, if a white piece is captured by the automated chessboard, the team loses 1 point. Should the team try an invalid movement, it loses 2 points. Each match ends with either of the 2 teams doing a checkmate (+3 points).

The winner team will have the opportunity to withdraw the liquidity, while distribution of sales is determined by the total points scored individually by each player, despite their team. This means that even players on the losing team have a chance to walk away with a share of the sales.

### Scoring

In this voting mechanism, each voter's exposure to the strategy they are voting on is determined by the square root of their voting power in relation to the square root of the total amount of voting power on the object at the time of voting.

For example, if an individual voter has a voting power of 1000 and the total amount of voting power on the object at the time of voting is 2000, the voter's exposure to the object would be 57%. If the same voter had a voting power of 100 and the total amount of voting power on the object was still 2000, their exposure to the object would be 36%.

Exposure: $\sqrt(1000)/\sqrt(2000+1000) = 0.57$

This voting mechanism allows for a more balanced and fair distribution of influence, as it ensures that each voter's impact is determined by their individual voting power and the overall context of the vote. It also ensures that strategists receive an undiluted portion of the score.


### Tokenomics

In this game, the tokenomics are designed to incentivize players to hold more tokens, even though they may have less weight individually.

There are two types of prizes in this game: **liquidity** and **sales**. Each badge is given a certain amount of liquidity, which is determined by the square root of the inputted ETH. Players may choose to add more ETH to their badges in order to increase their weight and improve their voting exposure.

However, speculators may choose to mint more badges with lower weights, expecting their team to win and diluting the ETH of heavier players. While a badge with a weight of 1 ETH will receive a prize that is only five times larger than that of a badge with a weight of 0.05 ETH, the liquidity of the heavier badges may still be diluted by the presence of numerous lighter badges.

This dynamic can lead to an increase in sales, as speculators accumulate more tokens and drive up demand. However, it is the liquidity that is diluted, while sales are distributed according to individual scores.

### Composability

Developers are invited to deploy strategies, that require to comply with the following interface:

```solidity
interface IButtPlug {
    function readMove(uint256 _board) external returns (uint256 _move);
    function owner() external returns (address _owner);
}
```

**Note**: the maximum amount of gas available to process a given strategy will decrease each match, starting with 10m gas units, and ending with 1m at match 9.

### Address Registry
ChessOlympiads: eth:0x2c217d709a9309b1d30323bace28438ede7e4e05
ChessOlympiadsForTest: goerli:0x2c217d709a9309b1d30323bace28438ede7e4e05

> Text partially generated by AI
