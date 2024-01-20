// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPool} from "https://github.com/aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

// chainlink imports
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
// import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

// import {IERC20 as CcipIERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";

contract PoolBorrow {
    IPool public immutable POOL =
        IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);
    address private daiAddress = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;
    IERC20 private dai = IERC20(daiAddress);
    // address payable owner;

    // new functions
    // address[] facilitators;
    bool[] isFacilitators;
    address[] allmembers;

    // chain error and events
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    // Event emitted when the tokens are transferred to an account on another chain.
    event TokensTransferred(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        address token, // The token address that was transferred.
        uint256 tokenAmount, // The token amount that was transferred.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the message.
    );

    // Mapping to keep track of allowlisted destination chains.
    mapping(uint64 => bool) public allowlistedChains;

    IRouterClient private s_router;
    IERC20 private s_linkToken;

    constructor() {
        // owner = payable(msg.sender);
        // facilitators.push(msg.sender); // added owner as facilator
        // isFacilitator[msg.sender] = true;
        isFacilitators.push(true);
        allmembers.push(msg.sender);
        s_router = IRouterClient(0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59);
        s_linkToken = IERC20(0x779877A7B0D9E8603169DdbD7836e478b4624789);
    }

    function getPool() public view returns (address) {
        return address(POOL);
    }

    function getAllMembers() public view returns (address[] memory) {
        return allmembers;
    }

    function checkIfFacilitator(address _account) public view returns (bool) {
        for (uint256 i = 0; i < allmembers.length; i++) {
            if (allmembers[i] == _account) {
                return true; // Address found, return the index
            }
        }
        return false;
    }

    function addFacilitator(address _account) public {
        // Check if msg.sender is in facilitators array
        require(checkIfFacilitator(msg.sender), "Sender is not a facilitator");
        allmembers.push(_account);
        isFacilitators.push(true);
    }

    function addMember(address _account) public {
        // Check if msg.sender is in facilitators array
        require(checkIfFacilitator(msg.sender), "Sender is not a facilitator");
        allmembers.push(_account);
        isFacilitators.push(false);
    }

    function toggleMemberState(address _account) public {
        require(checkIfFacilitator(msg.sender), "Sender is not a facilitator");

        int256 index = -1;

        for (uint256 i = 0; i < allmembers.length; i++) {
            if (allmembers[i] == _account) {
                index = int256(i); // Address found, return the index
            }
        }

        require(index >= 0, "address not found");
        isFacilitators[uint256(index)] = true;
    }

    function sendGHO(address _reciever, uint256 _amount) public {
        IERC20 ghoTokenAddress = IERC20(
            0xc4bF5CbDaBE595361438F8c6a187bDc330539c60
        );
        require(
            ghoTokenAddress.balanceOf(address(this)) >= _amount,
            "Insufficient GHO balance"
        );
        ghoTokenAddress.transfer(_reciever, _amount);
    }

    function supplyLiquidity(uint256 _amount) external {
        address asset = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;
        uint256 amount = _amount;
        address onBehalfOf = address(this);
        uint16 referralCode = 0;

        POOL.supply(asset, amount, onBehalfOf, referralCode);
    }

    function borrowGHO(uint256 amount) public {
        // POOL.borrow(0xc4bF5CbDaBE595361438F8c6a187bDc330539c60, amount, 2, 0, 0x3f93B8DCAf29D8B3202347018E23F76e697D8539);
        // Check if msg.sender is in facilitators array
        require(checkIfFacilitator(msg.sender), "Sender is not a facilitator");

        POOL.borrow(
            0xc4bF5CbDaBE595361438F8c6a187bDc330539c60,
            amount,
            2,
            0,
            address(this)
        );
    }

    function transferToMetamask(uint256 _amount) public {
        IERC20 ghoTokenAddress = IERC20(
            0xc4bF5CbDaBE595361438F8c6a187bDc330539c60
        );
        require(
            ghoTokenAddress.balanceOf(address(this)) >= _amount,
            "Insufficient GHO balance"
        );
        ghoTokenAddress.transfer(msg.sender, _amount);
    }

    function approveDAI(
        uint256 _amount,
        address _poolContractAddress
    ) external returns (bool) {
        return dai.approve(_poolContractAddress, _amount);
    }

    function allowanceDAI(
        address _poolContractAddress
    ) external view returns (uint256) {
        return dai.allowance(address(this), _poolContractAddress);
    }

    function getBalancGHO() external view returns (uint256) {
        return
            IERC20(0xc4bF5CbDaBE595361438F8c6a187bDc330539c60).balanceOf(
                address(this)
            );
    }

    function getBalanceOf(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    // Chain link functions

    modifier onlyAllowlistedChain(uint64 _destinationChainSelector) {
        if (!allowlistedChains[_destinationChainSelector])
            revert DestinationChainNotAllowlisted(_destinationChainSelector);
        _;
    }

    function allowlistDestinationChain(
        uint64 _destinationChainSelector,
        bool allowed
    ) external {
        allowlistedChains[_destinationChainSelector] = allowed;
    }

    function transferTokensPayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        address _token,
        uint256 _amount
    )
        external
        onlyAllowlistedChain(_destinationChainSelector)
        returns (bytes32 messageId)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        //  address(linkToken) means fees are paid in LINK
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _token,
            _amount,
            address(s_linkToken)
        );

        // Get the fee required to send the message
        uint256 fees = s_router.getFee(
            _destinationChainSelector,
            evm2AnyMessage
        );

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(s_router), fees);

        // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
        IERC20(_token).approve(address(s_router), _amount);

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend(
            _destinationChainSelector,
            evm2AnyMessage
        );

        // Emit an event with message details
        emit TokensTransferred(
            messageId,
            _destinationChainSelector,
            _receiver,
            _token,
            _amount,
            address(s_linkToken),
            fees
        );

        // Return the message ID
        return messageId;
    }

    function transferTokensPayNative(
        uint64 _destinationChainSelector,
        address _receiver,
        address _token,
        uint256 _amount
    )
        external
        onlyAllowlistedChain(_destinationChainSelector)
        returns (bytes32 messageId)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(0) means fees are paid in native gas
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _token,
            _amount,
            address(0)
        );

        // Get the fee required to send the message
        uint256 fees = s_router.getFee(
            _destinationChainSelector,
            evm2AnyMessage
        );

        if (fees > address(this).balance)
            revert NotEnoughBalance(address(this).balance, fees);

        // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
        IERC20(_token).approve(address(s_router), _amount);

        messageId = s_router.ccipSend{value: fees}(
            _destinationChainSelector,
            evm2AnyMessage
        );

        // Emit an event with message details
        emit TokensTransferred(
            messageId,
            _destinationChainSelector,
            _receiver,
            _token,
            _amount,
            address(0),
            fees
        );

        // Return the message ID
        return messageId;
    }

    function _buildCCIPMessage(
        address _receiver,
        address _token,
        uint256 _amount,
        address _feeTokenAddress
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        // Set the token amounts
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver), // ABI-encoded receiver address
                data: "", // No data
                tokenAmounts: tokenAmounts, // The amount and type of token being transferred
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit to 0 as we are not sending any data
                    Client.EVMExtraArgsV1({gasLimit: 0})
                ),
                feeToken: _feeTokenAddress
            });
    }

    function withdraw(address _beneficiary) public {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();
        (bool sent, ) = _beneficiary.call{value: amount}("");
        if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
    }

    function withdrawToken(address _beneficiary, address _token) public {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(_token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).transfer(_beneficiary, amount);
    }

    receive() external payable {}
}
