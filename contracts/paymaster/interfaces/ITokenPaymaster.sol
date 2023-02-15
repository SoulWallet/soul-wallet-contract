// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../interfaces/IPaymaster.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

interface ITokenPaymaster is IPaymaster, IERC165 {

    /**
     * @dev Emitted when token is added.
     */
    event TokenAdded(address token);

    /**
     * @dev Emitted when token is removed.
     */
    event TokenRemoved(address token);

    /**
     * @dev Returns the supported entrypoint.
     */
    function entryPoint() external view returns (address);
    

    /**
     * @dev Returns true if this contract supports the given token address.
     */
    function isSupportedToken(address _token) external view returns (bool);


    /**
     * @dev Returns the exchange price of the token in wei.
     */
    function exchangePrice(address _token) external view returns (uint256,uint8);


}
