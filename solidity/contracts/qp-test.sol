
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "./interfaces/IQuantumPortalPoc.sol";

interface IWETH {
    function deposit() external payable;
}

contract QPTest  {
    IQuantumPortalPoc public  portal;
    event DONE(uint);
    constructor(address _portal) {
        portal = IQuantumPortalPoc(_portal);
    }

    receive() external payable {}

    function justDoStuff() public payable {
        emit DONE(2299);
    }

    function runErc(uint fee) public payable {
        bytes memory data = abi.encodeWithSelector(this.runErc.selector);
        IERC20(0xE500820e95fD701f475fa3C0b5F1aE73e7bf1eD6).transfer(portal.feeTarget(), fee);
        portal.run(42161, address(this), msg.sender, data);
        emit DONE(101);
    }

    function runNative() public payable {
        IWETH(0xE500820e95fD701f475fa3C0b5F1aE73e7bf1eD6).deposit{value: msg.value / 2}();
        runErc(msg.value / 2);
        emit DONE(202);
    }

    function runDoubleNative() public payable {
        bytes memory data = abi.encodeWithSelector(this.runErc.selector);
        portal.runNativeFee{value: msg.value / 2}(42161, address(this), msg.sender, data);
        emit DONE(101);
    }

    function runBoth() external payable {
        runErc(msg.value);
        runNative();
    }

    event TransferResult(uint amount, address to, bool success);

    function testTransfer(uint amount, address payable to) external payable {
        amount = amount / 2;
        (bool success,) = to.call{value: amount}(new bytes(0));
        console.log('TransferResult', success);
        emit TransferResult(amount, to, success);
        bool success2 = to.send(amount);
        console.log('TransferResult', success2);
        emit TransferResult(amount, to, success2);
    }
}
