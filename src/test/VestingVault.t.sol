
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/VestingVault.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Demo Token", "DEMO") {
        _mint(msg.sender, 1000000 ether);
    }
}

contract VestingVaultTest is Test {
    VestingVault vault;
    TestToken token;

    address alice = address(0x1234);
    address bob = address(0x5678);

    uint64 start = 1000;
    uint64 cliff = 20;
    uint64 duration = 100;
    uint256 amount = 100 ether;

    function setUp() public {
        token = new TestToken();
        vault = new VestingVault(token);

        token.transfer(address(vault), 1000 ether);
        vm.warp(500);
    }

    function createDefaultSchedule() internal returns (uint256) {
        return vault.createSchedule(
            alice, amount, start, cliff, duration, true
        );
    }

    function testBeforeStart() public {
        uint256 id = createDefaultSchedule();
        vm.warp(900);
        assertEq(vault.vestedAmount(id), 0);
    }

    function testInsideCliff() public {
        uint256 id = createDefaultSchedule();
        vm.warp(1010);
        assertEq(vault.vestedAmount(id), 0);
    }

    function testAtCliff() public {
        uint256 id = createDefaultSchedule();
        vm.warp(1020);
        assertEq(vault.vestedAmount(id), 20 ether);
    }

    function testHalfway() public {
        uint256 id = createDefaultSchedule();
        vm.warp(1050);
        assertEq(vault.vestedAmount(id), 50 ether);
    }

    function testAtEnd() public {
        uint256 id = createDefaultSchedule();
        vm.warp(1100);
        assertEq(vault.vestedAmount(id), 100 ether);
    }

    function testAfterEnd() public {
        uint256 id = createDefaultSchedule();
        vm.warp(1200);
        assertEq(vault.vestedAmount(id), 100 ether);
    }

    function testMultipleReleases() public {
        uint256 id = createDefaultSchedule();

        vm.warp(1050);
        vault.release(id);
        assertEq(token.balanceOf(alice), 50 ether);

        vm.warp(1100);
        vault.release(id);

        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(vault.releasable(id), 0);
    }

    function testRevokeBeforeCliff() public {
        uint256 id = createDefaultSchedule();

        vm.warp(1010);
        vault.revoke(id);

        assertEq(vault.vestedAmount(id), 0);
        assertEq(vault.releasable(id), 0);
    }

    function testRevokeHalfway() public {
        uint256 id = createDefaultSchedule();

        vm.warp(1050);
        vault.revoke(id);

        assertEq(vault.vestedAmount(id), 50 ether);
        assertEq(vault.releasable(id), 50 ether);
    }

    function testRevokeAfterEnd() public {
        uint256 id = createDefaultSchedule();

        vm.warp(1200);
        vault.revoke(id);

        assertEq(vault.vestedAmount(id), 100 ether);
        assertEq(vault.releasable(id), 100 ether);
    }

    function testReleaseAfterRevoke() public {
        uint256 id = createDefaultSchedule();

        vm.warp(1050);
        vault.revoke(id);

        vm.warp(1200);
        vault.release(id);

        assertEq(token.balanceOf(alice), 50 ether);
        assertEq(vault.releasable(id), 0);
    }

    function testCannotOverAllocate() public {
        vm.expectRevert(
            bytes("not enough tokens")
        );

        vault.createSchedule(
            alice, 1001 ether, start, cliff, duration, true
        );
    }

    function testStrangerCannotCreate() public {
        vm.prank(bob);
        vm.expectRevert();
        vault.createSchedule(
            alice, amount, start, cliff, duration, true
        );
    }

    function testStrangerCannotRevoke() public {
        uint256 id = createDefaultSchedule();

        vm.prank(bob);
        vm.expectRevert();
        vault.revoke(id);
    }

    function testStrangerCannotWithdraw() public {
        vm.prank(bob);
        vm.expectRevert();
        vault.withdrawUnallocated(bob);
    }

    function testReleaseGoesToBeneficiary() public {
        uint256 id = createDefaultSchedule();

        vm.warp(1100);
        vm.prank(bob);
        vault.release(id);

        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.balanceOf(bob), 0);
    }

    function testFuzzVesting(
        uint96 randomAmount,
        uint64 randomTime
    ) public {
        uint256 value = bound(
            uint256(randomAmount), 1, 1000 ether
        );

        uint256 id = vault.createSchedule(
            alice, value, start, cliff, duration, true
        );

        uint256 t1 = bound(uint256(randomTime), 500, 1200);
        uint256 t2 = t1 + 100;

        vm.warp(t1);
        uint256 first = vault.vestedAmount(id);

        vm.warp(t2);
        uint256 second = vault.vestedAmount(id);

        assertLe(first, value);
        assertLe(second, value);
        assertGe(second, first);
    }
}
