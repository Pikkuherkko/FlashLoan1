# FlashLoan1
Works at least in Polygon Mainnet. Deploy to remix and GO!

First the contract will check if there are profitable trades. If yes, it takes a flash loan from AaveV2 (polygon) and executes the trades.
When deploying the contract to Remix, it needs addresses. I have collected some example addresses to constants.js. 

Next I should make a script that automates this process
