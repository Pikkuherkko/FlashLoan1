# FlashLoan1
Works at least in Polygon Mainnet. Deploy to remix and GO!

First the contract will check if there are profitable trades. If yes, it takes a flash loan from AaveV2 (polygon) and executes the trades.
When deploying the contract to Remix, it needs addresses. I have collected some example addresses to constants.js. 

Flashloan function is from Aave docs. The profitability check and arbitrage functions are copied as well but I don't remember where.

The next step is to build a bot that looks for arbitrage opportunities. I did it but it's hard to make it profitable.
