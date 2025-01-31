// SPDX-License-Identifier: MIT

/**
 *  @authors: [@shalzz]
 *  @reviewers: []
 *  @auditors: []
 *  @bounties: []
 *  @deployments: []
 */

pragma solidity ^0.8.0;

import "./interfaces/ISafeBridge.sol";
import "./interfaces/IFastBridgeSender.sol";
import "./interfaces/IFastBridgeReceiver.sol";

contract FastBridgeSender is IFastBridgeSender {
    ISafeBridge public safebridge;
    IFastBridgeReceiver public fastBridgeReceiver;
    address public fastSender;

    /**
     * The bridgers need to watch for these events and
     * relay the messageHash on the FastBridgeReceiver.
     */
    event OutgoingMessage(address target, bytes32 messageHash, bytes message);

    constructor(ISafeBridge _safebridge, IFastBridgeReceiver _fastBridgeReceiver) {
        safebridge = _safebridge;
        fastBridgeReceiver = _fastBridgeReceiver;
    }

    function setFastSender(address _fastSender) external {
        require(fastSender == address(0));
        fastSender = _fastSender;
    }

    /**
     * Sends an arbitrary message from one domain to another
     * via the fast bridge mechanism
     *
     * @param _receiver The L1 contract address who will receive the calldata
     * @param _calldata The receiving domain encoded message data.
     */
    function sendFast(address _receiver, bytes memory _calldata) external {
        require(msg.sender == fastSender, "Access not allowed: Fast Sender only.");

        // Encode the receiver address with the function signature + arguments i.e calldata
        bytes memory encodedData = abi.encode(_receiver, _calldata);

        emit OutgoingMessage(_receiver, keccak256(encodedData), encodedData);
    }

    /**
     * Sends an arbitrary message from one domain to another
     * via the safe bridge mechanism, which relies on the chain's native bridge.
     *
     * It is unnecessary during normal operations but essential only in case of challenge.
     *
     * It may require some ETH (or whichever native token) to pay for the bridging cost,
     * depending on the underlying safe bridge.
     *
     * @param _receiver The L1 contract address who will receive the calldata
     * @param _calldata The receiving domain encoded message data.
     */
    function sendSafe(address _receiver, bytes memory _calldata) external payable {
        // The safe bridge sends the encoded data to the FastBridgeReceiver
        // in order for the FastBridgeReceiver to resolve any potential
        // challenges and then forwards the message to the actual
        // intended recipient encoded in `data`
        // TODO: For this encodedData needs to be wrapped into an
        // IFastBridgeReceiver function.
        // TODO: add access checks for this on the FastBridgeReceiver.
        // TODO: how much ETH should be provided for bridging? add an ISafeBridge.bridgingCost()
        bytes memory encodedData = abi.encode(_receiver, _calldata);
        safebridge.sendSafe{value: msg.value}(address(fastBridgeReceiver), encodedData);
    }
}
