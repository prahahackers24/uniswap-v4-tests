// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolBatchSwapTest} from "v4-core/src/test/PoolBatchSwapTest.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

contract SwapScript is Script {
    // PoolSwapTest Contract address on Goerli
    PoolBatchSwapTest swapRouter =
        PoolBatchSwapTest(0x3f1e9D9cfdB1b44feD1769C02C6AE5Bb97aF7E34);

    address constant MUNI_ADDRESS =
        address(0xc268035619873d85461525F5fDb792dd95982161); //-- insert your own contract address here -- mUNI deployed to GOERLI
    address constant MUSDC_ADDRESS =
        address(0xbe2a7F5acecDc293Bf34445A0021f229DD2Edd49); //-- insert your own contract address here -- mUSDC deployed to GOERLI
    address constant HOOK_ADDRESS =
        address(0x0000000000000000000000000000000000000000); // address of the hook contract deployed to goerli -- you can use this hook address or deploy your own!

    // slippage tolerance to allow for unlimited price impact
    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;

    function run() external {
        address token0 = uint160(MUSDC_ADDRESS) < uint160(MUNI_ADDRESS)
            ? MUSDC_ADDRESS
            : MUNI_ADDRESS;
        address token1 = uint160(MUSDC_ADDRESS) < uint160(MUNI_ADDRESS)
            ? MUNI_ADDRESS
            : MUSDC_ADDRESS;
        uint24 swapFee = 500;
        int24 tickSpacing = 10;

        // Using a hooked pool
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(HOOK_ADDRESS)
        });

        // approve tokens to the swap router
        vm.broadcast();
        IERC20(token0).approve(address(swapRouter), type(uint256).max);
        vm.broadcast();
        IERC20(token1).approve(address(swapRouter), type(uint256).max);

        // ---------------------------- //
        // Swap 100e18 token0 into token1 //
        // ---------------------------- //
        bool zeroForOne = false;
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: 10_000_000_000_000_000_000,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });

        // in v4, users have the option to receieve native ERC20s or wrapped ERC1155 tokens
        // here, we'll take the ERC20s
        PoolBatchSwapTest.TestSettings memory testSettings = PoolBatchSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        bytes memory hookData = new bytes(0);
        vm.broadcast();
        PoolKey[] memory keys = new PoolKey[](1);
        keys[0] = pool;

        IPoolManager.SwapParams[]
            memory swap_params = new IPoolManager.SwapParams[](1);
        swap_params[0] = params;
        swapRouter.swap(keys, swap_params, testSettings, hookData);
    }
}
