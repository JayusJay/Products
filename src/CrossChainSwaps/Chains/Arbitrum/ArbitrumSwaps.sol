//SPDX-License-Identifier: ISC

pragma solidity ^0.8.13;

import "../../adapters/UniswapAdapter.sol";
import "../../adapters/SushiAdapter.sol";
import "../../adapters/XCaliburAdapter.sol";
import "./StargateArbitrum.sol";
import {IWETH9} from "../../interfaces/IWETH9.sol";
import {IERC20} from "openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IArbitrumSwaps} from "./interfaces/IArbitrumSwaps.sol";

contract ArbitrumSwaps is UniswapAdapter, SushiLegacyAdapter, XCaliburAdapter, StargateArbitrum, IArbitrumSwaps {
    using SafeERC20 for IERC20;

    error MoreThanZero();

    IWETH9 internal immutable weth;

    //Constants

    uint8 internal constant BATCH_DEPOSIT = 1;
    uint8 internal constant WETH_DEPOSIT = 2;
    uint8 internal constant UNI_SINGLE = 3;
    uint8 internal constant UNI_MULTI = 4;
    uint8 internal constant SUSHI_LEGACY = 5;
    uint8 internal constant SUSHI_TRIDENT = 6;
    uint8 internal constant XCAL = 7;
    uint8 internal constant SRC_TRANSFER = 8;
    uint8 internal constant WETH_WITHDRAW = 9;
    uint8 internal constant STARGATE = 10;

    constructor(address _weth, ISwapRouter _swapRouter, address _factory, bytes32 _pairCodeHash, address _xcalFactory, IStargateRouter _stargateRouter) 
    UniswapAdapter(_swapRouter)
    SushiLegacyAdapter(_factory, _pairCodeHash) 
    XCaliburAdapter(_xcalFactory, _weth)
    StargateArbitrum(_stargateRouter)
    {
        weth = IWETH9(_weth);
    }

    function arbitrumSwaps(uint8[] calldata steps, bytes[] calldata data) external payable {
        for (uint256 i; i < steps.length; i++) {
            uint8 step = steps[i];
            if (step == BATCH_DEPOSIT) {
                (address[] memory tokens, uint256[] memory amounts) = abi
                    .decode(data[i], (address[], uint256[]));

                for (uint256 j; j < tokens.length; j++) {
                    if (amounts[j] <= 0) revert MoreThanZero();
                    IERC20(tokens[j]).safeTransferFrom(
                        msg.sender,
                        address(this),
                        amounts[j]
                    );
                }
            } else if (step == WETH_DEPOSIT) {
                uint256 _amount = abi.decode(data[i], (uint256));
                if (_amount <= 0) revert MoreThanZero();
                IWETH9(weth).deposit{value: _amount}();
            } else if (step == UNI_SINGLE) {
                UniswapV3Single[] memory params = abi.decode(
                    data[i],
                    (UniswapV3Single[])
                );
                for (uint256 j; j < params.length; j++) {
                    UniswapV3Single memory swapData = params[j];
                    swapExactInputSingle(swapData);
                }
            } else if (step == UNI_MULTI) {
                UniswapV3Multi[] memory params = abi.decode(
                    data[i],
                    (UniswapV3Multi[])
                );
                for (uint256 j; j < params.length; j++) {
                    
                    swapExactInputMultihop(params[j]);
                }
            } else if (step == SUSHI_LEGACY) {
                SushiParams[] memory params = abi.decode(
                    data[i],
                    (SushiParams[])
                );
                for (uint256 j; j < params.length; j++) {
                    _swapExactTokensForTokens(params[j]);
                }
            }
        }
    }

    receive() external payable {}
}