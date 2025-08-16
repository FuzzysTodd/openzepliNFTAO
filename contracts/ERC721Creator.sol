// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)
// Enhanced with additional features, optimizations, and improved documentation

pragma solidity ^0.8.1;

/**
 * @title Address
 * @dev Collection of functions related to the address type with enhanced functionality
 * @custom:security-contact security@example.com
 */
library Address {
    // ====== EVENTS ======
    
    /**
     * @dev Emitted when ETH is sent to an address using the sendValue function
     * @param sender The address that initiated the transfer
     * @param recipient The address that received the ETH
     * @param amount The amount of ETH sent in wei
     */
    event ValueSent(address indexed sender, address indexed recipient, uint256 amount);
    
    /**
     * @dev Emitted when a batch of ETH transfers is executed
     * @param sender The address that initiated the transfers
     * @param recipientCount The number of recipients
     * @param totalAmount The total amount of ETH sent
     */
    event BatchValueSent(address indexed sender, uint256 recipientCount, uint256 totalAmount);
    
    /**
     * @dev Emitted when a function call to a contract is made
     * @param target The contract address that was called
     * @param value The amount of ETH sent with the call
     * @param data The call data
     */
    event ContractCalled(address indexed target, uint256 value, bytes data);

    // ====== CONSTANTS ======
    
    /**
     * @dev Maximum batch size for batch operations to prevent gas limit issues
     */
    uint256 private constant MAX_BATCH_SIZE = 100;

    // ====== ADDRESS VERIFICATION ======
    
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     * 
     * @param account The address to check
     * @return True if the account is a contract, false otherwise
     */
    function isContract(address account) internal view returns (bool) {
        // Gas optimized version using assembly to check extcodesize
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    
    /**
     * @dev Checks if an address is not the zero address.
     * Useful for validating address inputs and preventing common errors.
     * 
     * @param account The address to check
     * @return True if the account is not the zero address, false otherwise
     */
    function isNotZeroAddress(address account) internal pure returns (bool) {
        return account != address(0);
    }
    
    /**
     * @dev Validates that an address is not the zero address, reverting if it is.
     * 
     * @param account The address to validate
     * @param errorMessage The error message to revert with if validation fails
     */
    function requireNotZeroAddress(address account, string memory errorMessage) internal pure {
        require(isNotZeroAddress(account), errorMessage);
    }

    /**
     * @dev Checks if an address has a minimum ETH balance.
     * 
     * @param account The address to check
     * @param minBalance The minimum balance required
     * @return True if the account has at least the minimum balance, false otherwise
     */
    function hasMinBalance(address account, uint256 minBalance) internal view returns (bool) {
        return account.balance >= minBalance;
    }

    // ====== ETH TRANSFER FUNCTIONS ======
    
    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     * 
     * @param recipient The address to send ETH to
     * @param amount The amount of ETH to send in wei
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        // Validate inputs
        requireNotZeroAddress(recipient, "Address: cannot send value to zero address");
        require(address(this).balance >= amount, 
            string(abi.encodePacked(
                "Address: insufficient balance for transfer (balance: ", 
                _toString(address(this).balance), 
                ", amount: ", 
                _toString(amount), 
                ")"
            ))
        );

        // Perform the transfer
        (bool success, ) = recipient.call{value: amount}("");
        
        // Check result
        require(success, string(abi.encodePacked(
            "Address: failed to send value to ", 
            _addressToString(recipient), 
            " with amount ", 
            _toString(amount)
        )));
        
        // Emit event
        emit ValueSent(address(this), recipient, amount);
    }
    
    /**
     * @dev Sends ETH to multiple recipients in a single transaction.
     * Reverts if any individual transfer fails.
     * Limits batch size to prevent gas limit issues.
     * 
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to send to each recipient
     */
    function sendValueToMultiple(
        address payable[] memory recipients, 
        uint256[] memory amounts
    ) internal {
        // Validate inputs
        require(recipients.length == amounts.length, 
            "Address: recipients and amounts arrays must have the same length");
        require(recipients.length <= MAX_BATCH_SIZE, 
            string(abi.encodePacked(
                "Address: batch size exceeds maximum (", 
                _toString(recipients.length), 
                " > ", 
                _toString(MAX_BATCH_SIZE), 
                ")"
            ))
        );
        
        // Calculate total amount needed
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        // Check if contract has enough balance
        require(address(this).balance >= totalAmount, 
            string(abi.encodePacked(
                "Address: insufficient balance for batch transfer (balance: ", 
                _toString(address(this).balance), 
                ", required: ", 
                _toString(totalAmount), 
                ")"
            ))
        );
        
        // Perform transfers
        for (uint256 i = 0; i < recipients.length; i++) {
            address payable recipient = recipients[i];
            uint256 amount = amounts[i];
            
            requireNotZeroAddress(recipient, "Address: cannot send to zero address");
            
            (bool success, ) = recipient.call{value: amount}("");
            require(success, string(abi.encodePacked(
                "Address: batch transfer failed at index ", 
                _toString(i), 
                " to ", 
                _addressToString(recipient), 
                " with amount ", 
                _toString(amount)
            )));
            
            emit ValueSent(address(this), recipient, amount);
        }
        
        emit BatchValueSent(address(this), recipients.length, totalAmount);
    }
    
    /**
     * @dev Sends the same amount of ETH to multiple recipients.
     * 
     * @param recipients Array of recipient addresses
     * @param amount Amount to send to each recipient
     */
    function sendSameValueToMultiple(
        address payable[] memory recipients, 
        uint256 amount
    ) internal {
        require(recipients.length <= MAX_BATCH_SIZE, 
            string(abi.encodePacked(
                "Address: batch size exceeds maximum (", 
                _toString(recipients.length), 
                " > ", 
                _toString(MAX_BATCH_SIZE), 
                ")"
            ))
        );
        
        uint256 totalAmount = amount * recipients.length;
        require(address(this).balance >= totalAmount, 
            string(abi.encodePacked(
                "Address: insufficient balance for batch transfer (balance: ", 
                _toString(address(this).balance), 
                ", required: ", 
                _toString(totalAmount), 
                ")"
            ))
        );
        
        for (uint256 i = 0; i < recipients.length; i++) {
            address payable recipient = recipients[i];
            requireNotZeroAddress(recipient, "Address: cannot send to zero address");
            
            (bool success, ) = recipient.call{value: amount}("");
            require(success, string(abi.encodePacked(
                "Address: batch transfer failed at index ", 
                _toString(i), 
                " to ", 
                _addressToString(recipient)
            )));
            
            emit ValueSent(address(this), recipient, amount);
        }
        
        emit BatchValueSent(address(this), recipients.length, totalAmount);
    }

    // ====== CONTRACT CALL FUNCTIONS ======
    
    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     * 
     * @param target The address to call
     * @param data The call data
     * @return The return data of the call
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     * 
     * @param target The address to call
     * @param data The call data
     * @param errorMessage Error message to use if the call fails
     * @return The return data of the call
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     * 
     * @param target The address to call
     * @param data The call data
     * @param value The amount of ETH to send with the call
     * @return The return data of the call
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     * 
     * @param target The address to call
     * @param data The call data
     * @param value The amount of ETH to send with the call
     * @param errorMessage Error message to use if the call fails
     * @return The return data of the call
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        requireNotZeroAddress(target, "Address: call to zero address");
        require(address(this).balance >= value, 
            string(abi.encodePacked(
                "Address: insufficient balance for call (balance: ", 
                _toString(address(this).balance), 
                ", value: ", 
                _toString(value), 
                ")"
            ))
        );
        
        // Emit event before making the call
        emit ContractCalled(target, value, data);
        
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     * 
     * @param target The address to call
     * @param data The call data
     * @return The return data of the call
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     * 
     * @param target The address to call
     * @param data The call data
     * @param errorMessage Error message to use if the call fails
     * @return The return data of the call
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        requireNotZeroAddress(target, "Address: static call to zero address");
        
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     * 
     * @param target The address to call
     * @param data The call data
     * @return The return data of the call
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     * 
     * @param target The address to call
     * @param data The call data
     * @param errorMessage Error message to use if the call fails
     * @return The return data of the call
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        requireNotZeroAddress(target, "Address: delegate call to zero address");
        
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     * 
     * @param target The address that was called
     * @param success Whether the call was successful
     * @param returndata The return data from the call
     * @param errorMessage Error message to use if the call fails
     * @return The return data from the call if successful
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     * 
     * @param success Whether the call was successful
     * @param returndata The return data from the call
     * @param errorMessage Error message to use if the call fails
     * @return The return data from the call if successful
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    // ====== SAFE CONTRACT INTERACTION HELPERS ======
    
    /**
     * @dev Safely executes a function on a contract with reentrancy protection.
     * This is a convenience wrapper that combines functionCall with a reentrancy check.
     * Note: This does not actually implement the reentrancy guard - the calling contract
     * must handle the reentrancy protection mechanism.
     * 
     * @param target The address to call
     * @param data The call data
     * @param errorMessage Error message to use if the call fails
     * @return The return data of the call
     */
    function safeContractCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        // The calling contract should implement reentrancy protection before calling this
        return functionCall(target, data, errorMessage);
    }
    
    /**
     * @dev Executes multiple contract calls in a batch.
     * All calls must succeed or the entire operation reverts.
     * 
     * @param targets Array of addresses to call
     * @param data Array of call data for each target
     * @return results Array of return data from each call
     */
    function batchContractCall(
        address[] memory targets,
        bytes[] memory data
    ) internal returns (bytes[] memory results) {
        require(targets.length == data.length, "Address: targets and data arrays must have the same length");
        require(targets.length <= MAX_BATCH_SIZE, "Address: batch size exceeds maximum");
        
        results = new bytes[](targets.length);
        
        for (uint256 i = 0; i < targets.length; i++) {
            results[i] = functionCall(
                targets[i],
                data[i],
                string(abi.encodePacked("Address: batch call failed at index ", _toString(i)))
            );
        }
        
        return results;
    }

    // ====== UTILITY FUNCTIONS ======
    
    /**
     * @dev Converts an address to its string representation.
     * 
     * @param addr The address to convert
     * @return The string representation of the address
     */
    function _addressToString(address addr) internal pure returns (string memory) {
        bytes memory addressBytes = abi.encodePacked(addr);
        bytes memory stringBytes = new bytes(42);
        
        stringBytes[0] = '0';
        stringBytes[1] = 'x';
        
        for (uint256 i = 0; i < 20; i++) {
            uint8 leftNibble = uint8(addressBytes[i]) >> 4;
            uint8 rightNibble = uint8(addressBytes[i]) & 0xf;
            
            stringBytes[2 + i * 2] = _charToHexChar(leftNibble);
            stringBytes[2 + i * 2 + 1] = _charToHexChar(rightNibble);
        }
        
        return string(stringBytes);
    }
    
    /**
     * @dev Converts a uint256 to its string representation.
     * 
     * @param value The uint256 to convert
     * @return The string representation of the uint256
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
    
    /**
     * @dev Converts a byte to its hexadecimal character representation.
     * 
     * @param value The byte value to convert (0-15)
     * @return The hexadecimal character
     */
    function _charToHexChar(uint8 value) internal pure returns (bytes1) {
        if (value < 10) {
            return bytes1(uint8(48 + value)); // 0-9
        } else {
            return bytes1(uint8(87 + value)); // a-f
        }
    }

    /**
     * @dev Internal function to revert with a reason.
     * 
     * @param returndata The return data from the call
     * @param errorMessage Error message to use if the call fails
     */
    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}