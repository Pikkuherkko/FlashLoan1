// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import { FlashLoanReceiverBase } from "./FlashloanReceiverBase.sol";
import { ILendingPool, ILendingPoolAddressesProvider, IERC20, IUniswapV2Router02 } from "./Interfaces.sol";

import { SafeMath } from "./Libraries.sol";

contract FlashLoanArbitrage is FlashLoanReceiverBase {

    address public owner;

    address public wethAddress;
    address public daiAddress;
    address public uniswapRouterAddress;
    address public sushiswapRouterAddress;

    enum Exchange {UNI, SUSHI, NONE}

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _addressProvider, address _uniswapRouterAddress, address _sushiswapRouterAddress, address _weth, address _dai) 
    public FlashLoanReceiverBase(_addressProvider)
    {
        uniswapRouterAddress = _uniswapRouterAddress;
        sushiswapRouterAddress = _sushiswapRouterAddress;
        owner = msg.sender;
        wethAddress = _weth;
        daiAddress = _dai;
    }

    function deposit(uint256 amount) public onlyOwner {
        require(amount > 0, ">0");
        IERC20(wethAddress).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw() public onlyOwner {
        IERC20(wethAddress).transferFrom(address(this), msg.sender, getERC20Balance(wethAddress));
    }

    function makeArbitrage() public {
        uint256 amountIn = getERC20Balance(wethAddress);
        Exchange result = _comparePrice(amountIn);
        if (result == Exchange.UNI) {
            uint256 amountOut = _swap(
                amountIn,
                uniswapRouterAddress,
                wethAddress,
                daiAddress
            );
            _swap(amountOut, sushiswapRouterAddress, daiAddress, wethAddress);
        } else if (result == Exchange.SUSHI) {
            uint256 amountOut = _swap(
                amountIn,
                sushiswapRouterAddress,
                wethAddress,
                daiAddress
            );
            _swap(amountOut, uniswapRouterAddress, daiAddress, wethAddress);
        }
    }

    function _swap(uint256 amountIn, address routerAddress, address sell_token, address buy_token) 
    internal returns (uint256) {
        IERC20(sell_token).approve(routerAddress, amountIn);
        uint256 amountOutMin = (_getPrice(routerAddress, sell_token, buy_token, amountIn) * 95) / 100;
        address[] memory path = new address[](2);
        path[0] = sell_token;
        path[1] = buy_token;
        uint256 amountOut = IUniswapV2Router02(routerAddress)
            .swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), block.timestamp)[1];
        return amountOut;
    }

    function _comparePrice(uint256 amount) internal view returns (Exchange) {
        uint256 uniswapPrice = _getPrice(uniswapRouterAddress, wethAddress, daiAddress, amount);
        uint256 sushiswapPrice = _getPrice(sushiswapRouterAddress, wethAddress, daiAddress, amount);
        if (uniswapPrice > sushiswapPrice) {
            require(_checkProfitability(amount, uniswapPrice, sushiswapPrice), "Not profitable (1)");
            return Exchange.UNI;
        } else if (uniswapPrice < sushiswapPrice) {
            require(_checkProfitability(amount, sushiswapPrice, uniswapPrice), "Not profitable (2)");
            return Exchange.SUSHI;
        } else {
            return Exchange.NONE;
        }
    }

    function _checkProfitability(uint256 amountIn, uint256 higherPrice, uint256 lowerPrice) 
    internal pure returns (bool) {
        uint256 difference = ((higherPrice - lowerPrice) * 10**18) / higherPrice; 
        uint256 payed_fee = (2 * (amountIn * 3)) / 1000;
        if (difference > payed_fee) {
            return true;
        } else {
            return false;
        }
    }

    function _getPrice(address routerAddress, address sell_token, address buy_token, uint256 amount) 
    internal view returns (uint256) {
        address[] memory pairs = new address[](2);
        pairs[0] = sell_token;
        pairs[1] = buy_token;
        uint256 price = IUniswapV2Router02(routerAddress).getAmountsOut(amount, pairs)[1];
        return price;
    }

    // flashloan functions
 
    /**
     * @dev This function must be called only be the LENDING_POOL and takes care of repaying
     * active debt positions, migrating collateral and incurring new V2 debt token debt.
     *
     * @param assets The array of flash loaned assets used to repay debts.
     * @param amounts The array of flash loaned asset amounts used to repay debts.
     * @param premiums The array of premiums incurred as additional debts.
     * @param initiator The address that initiated the flash loan, unused.
     * @param params The byte array containing, in this case, the arrays of aTokens and aTokenAmounts.
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        
        //
        // This contract now has the funds requested.
        // Your logic goes here.
        //
        
        // At the end of your logic above, this contract owes
        // the flashloaned amounts + premiums.
        // Therefore ensure your contract has enough to repay
        // these amounts.
        makeArbitrage();
        
        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);
            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }

        return true;
    }

    function _flashloan(address[] memory assets, uint256[] memory amounts) internal {
        address receiverAddress = address(this);

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        uint256[] memory modes = new uint256[](assets.length);

        // 0 = no debt (flash), 1 = stable, 2 = variable
        for (uint256 i = 0; i < assets.length; i++) {
            modes[i] = 0;
        }

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    /*
     *  Flash loan wei amount worth of `_asset`
     */
    function flashloan(address _asset, uint256 _amount) public onlyOwner {
        bytes memory data = "";
        uint amount = _amount;

        address[] memory assets = new address[](1);
        assets[0] = _asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        _flashloan(assets, amounts);
    }

    // GETTER functions

    function getERC20Balance(address _erc20Address) public view returns(uint256) {
        return IERC20(_erc20Address).balanceOf(address(this));
    }
}