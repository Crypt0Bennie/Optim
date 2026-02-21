// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "./interfaces/ICLPool.sol";
import "./libraries/LowGasSafeMath.sol";
import "./libraries/SafeCast.sol";
import "./libraries/Tick.sol";
import "./libraries/TickBitmap.sol";
import "./libraries/Position.sol";
import "./libraries/Oracle.sol";
import "./interfaces/ICLPool.sol";
import "./libraries/FullMath.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/TickMath.sol";



interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function decimals() external view returns (uint8);
}

contract VeloOracle {

ICLPoolDerivedState public V3Pool;


function getPrice(address pool) public view returns (uint256 price) {
    require(pool != address(0), "Invalid pool address");

    address token0 = ICLPool(pool).token0();
    address token1 = ICLPool(pool).token1();
    require(token0 != address(0) && token1 != address(0), "Invalid tokens");

    uint8 dec0 = IERC20(token0).decimals();
    uint8 dec1 = IERC20(token1).decimals();

    (, int24 tick, , , , ) = ICLPoolState(pool).slot0();

    uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);
    if (sqrtRatioX96 == 0) return 0;

    // price = amount of token1 per 1 token0, with 18-decimal precision
    // Step 1: (sqrtRatioX96)^2 / 2^192
    uint256 ratioX192 = FullMath.mulDiv(
        uint256(sqrtRatioX96),
        uint256(sqrtRatioX96),
        1 << 192
    );

    // Step 2: scale to 18 decimals
    uint256 priceRaw = FullMath.mulDiv(ratioX192, 10**18, 1);

    // Step 3: adjust for token decimals difference
    // We want price with 18 decimals → if dec1 > dec0, divide more; if dec0 > dec1, multiply more
    uint256 adjust;
    if (dec1 > dec0) {
        adjust = 10 ** uint256(dec1 - dec0);
        price = priceRaw / adjust;
    } else if (dec0 > dec1) {
        adjust = 10 ** uint256(dec0 - dec1);
        price = FullMath.mulDiv(priceRaw, adjust, 1);
    } else {
        price = priceRaw;
    }

    // Optional: if you want price of token0 quoted in token1 units (more common for WETH/USDC)
    // price = FullMath.mulDiv(10**36, 1, price);  // 1e18 * 1e18 / price

    return price;
}

}