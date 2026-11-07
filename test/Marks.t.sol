// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GodsOfIMDInhabitants} from "../src/GodsOfIMDInhabitants.sol";

contract TestIMD is ERC20 {
    constructor() ERC20("IMD", "IMD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// The Marks: a fixed deck of 1000 (640 Mortal, 250 Blessed, 100 Ascended, 10 Divine), drawn after the forge
/// from a block hash nobody knew at forge time, with better odds for the first souls.
contract MarksTest is Test {
    TestIMD imd;
    GodsOfIMDInhabitants nft;
    address owner = address(0xA11CE);
    address shrine = address(0x5A1);
    address burn = address(0xB0);
    address player = address(0xBEEF);
    uint16[4] caps = [uint16(640), 250, 100, 10];

    function setUp() public {
        imd = new TestIMD();
        nft = new GodsOfIMDInhabitants(owner, IERC20(address(imd)), shrine, burn);
        vm.prank(owner);
        nft.setPhase(GodsOfIMDInhabitants.Phase.Public);
        imd.mint(player, 1_000_000 ether);
        vm.prank(player);
        imd.approve(address(nft), type(uint256).max);
    }

    function _forge(uint256 i) internal returns (uint256 id) {
        vm.prank(player);
        id = nft.forge(keccak256(abi.encode("soul", i)), address(0));
    }

    function test_genesisRulesAreBuiltIn() public view {
        assertEq(nft.maxSupply(), 1000);
        assertEq(nft.GENESIS_SUPPLY(), 1000);
        for (uint256 m; m < 4; ++m) assertEq(nft.markCap(m), caps[m]);
        assertEq(nft.mintPrice(), 5 ether);
        assertEq(nft.allowlistPrice(), 4 ether);
        GodsOfIMDInhabitants.Payee[] memory p = nft.payees();
        assertEq(p.length, 1);
        assertEq(p[0].account, owner);
        assertEq(p[0].bps, 7000);
        (address to, uint256 fee) = nft.royaltyInfo(1, 100 ether);
        assertEq(to, owner);
        assertEq(fee, 5 ether);
    }

    function test_cannotRevealBeforeTheHashExists() public {
        uint256 id = _forge(1);
        assertEq(uint8(nft.markOf(id)), uint8(GodsOfIMDInhabitants.Mark.Unrevealed));
        vm.expectRevert(abi.encodeWithSelector(GodsOfIMDInhabitants.NotRevealable.selector, id));
        nft.reveal(id); // the forge block
        vm.roll(block.number + 1);
        vm.expectRevert(abi.encodeWithSelector(GodsOfIMDInhabitants.NotRevealable.selector, id));
        nft.reveal(id); // the block whose hash decides: still unknown inside it
        vm.roll(block.number + 1);
        nft.reveal(id);
        assertTrue(nft.markOf(id) != GodsOfIMDInhabitants.Mark.Unrevealed);
        vm.expectRevert(abi.encodeWithSelector(GodsOfIMDInhabitants.NotRevealable.selector, id));
        nft.reveal(id); // only once
    }

    function test_revealManySkipsWhatIsNotReady() public {
        uint256 a = _forge(1);
        vm.roll(block.number + 2);
        uint256 b = _forge(2);
        uint256[] memory ids = new uint256[](2);
        ids[0] = a;
        ids[1] = b;
        nft.revealMany(ids);
        assertTrue(nft.markOf(a) != GodsOfIMDInhabitants.Mark.Unrevealed);
        assertEq(uint8(nft.markOf(b)), uint8(GodsOfIMDInhabitants.Mark.Unrevealed));
    }

    function test_fullDeckComesOutExactly() public {
        uint256 total;
        for (uint256 i = 1; i <= 1000; ++i) {
            vm.prevrandao(bytes32(i * 7919));
            uint256 id = _forge(i);
            vm.roll(block.number + 2);
            nft.reveal(id);
            total++;
        }
        assertEq(total, 1000);
        for (uint256 m; m < 4; ++m) assertEq(nft.markRevealed(m), caps[m]);
        vm.expectRevert(abi.encodeWithSelector(GodsOfIMDInhabitants.MaxSupplyReached.selector, 1000));
        _forge(1001);
    }

    function test_earlyBoostWaves() public view {
        assertEq(nft.earlyBoost(1), 5);
        assertEq(nft.earlyBoost(10), 5);
        assertEq(nft.earlyBoost(11), 3);
        assertEq(nft.earlyBoost(50), 3);
        assertEq(nft.earlyBoost(51), 2);
        assertEq(nft.earlyBoost(150), 2);
        assertEq(nft.earlyBoost(151), 1);
        assertEq(nft.earlyBoost(1000), 1);
    }

    /// Early souls draw rare Marks far more often than late ones (many independent decks).
    function test_earlySoulsAreLuckier() public {
        uint256 earlyRare;
        uint256 lateRare;
        for (uint256 run; run < 6; ++run) {
            setUp();
            for (uint256 i = 1; i <= 200; ++i) {
                vm.roll(block.number + 1);
                uint256 id = _forge(run * 1000 + i);
                vm.roll(block.number + 2);
                nft.reveal(id);
                bool rare = nft.markOf(id) != GodsOfIMDInhabitants.Mark.Mortal;
                if (rare && i <= 10) earlyRare++;
                if (rare && i > 150) lateRare++;
            }
        }
        // 10 early souls vs 50 late souls per run: compare rates
        uint256 earlyRate = (earlyRare * 1e6) / (6 * 10);
        uint256 lateRate = (lateRare * 1e6) / (6 * 50);
        emit log_named_uint("early rare rate (ppm)", earlyRate);
        emit log_named_uint("late rare rate (ppm)", lateRate);
        assertGt(earlyRate, lateRate * 15 / 10);
    }
}
