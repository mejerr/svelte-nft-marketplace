// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

interface IMarketPlace {
    enum TokenStatus {
        ForSale,
        Idle
    }

    enum BidStatus {
        Accepted,
        Rejected,
        Idle
    }

    struct Creator {
        string name;
        string image;
    }

    struct Collection {
        uint256 collectionId;
        string name;
        string description;
        address creator;
        string image;
    }

    struct MarketItem {
        uint256 tokenId;
        string name;
        string description;
        uint256 price;
        uint256 collectionId;
        TokenStatus status;
    }

    struct Bid {
        uint256 bidId;
        uint256 amount;
        address payable bidder;
        BidStatus status;
    }

    event CollectionCreated(uint256 indexed collectionId, address creator);

    event TokenMinted(
        uint256 indexed tokenId,
        uint256 price,
        uint256 collectionId
    );

    event CreateMarketSale(uint256 tokenId, uint256 price);
    event CancelMarketSale(uint256 tokenId);

    event ItemBought(
        uint256 indexed tokenId,
        address buyer,
        address owner,
        uint256 price
    );

    event BidCreated(uint256 indexed bidId, uint256 price, address bidder);
    event BidAccepted(
        uint256 indexed tokenId,
        uint256 indexed bidId,
        uint256 amount,
        address bidder
    );

    event CreatorNameChanged(string name, address creator);
    event CreatorImageChanged(string image, address creator);

    event ListingFeeToOwner(uint256 listingFee);
    event Deposit(uint256 price);

    event BidCancelled(
        uint256 indexed tokenId,
        uint256 indexed bidId,
        address canceller
    );

    function changeCreatorName(string calldata name) external;

    function changeCreatorImage(string calldata image) external;

    function getListingFee() external view returns (uint256);

    function getCollectedListingFee() external view returns (uint256);

    function transferListingFee() external payable;

    function createCollection(
        string calldata image,
        string calldata name,
        string calldata description
    ) external;

    function getCollectionLength() external view returns (uint256);

    function mintToken(
        string memory tokenURI,
        string calldata name,
        string calldata description,
        uint256 collectionId
    ) external payable;

    function getMarketItemsLength() external view returns (uint256);

    function createSale(uint256 tokenId, uint256 _price) external payable;

    function cancelSale(uint256 tokenId) external;

    function buyMarketItem(uint256 tokenId) external payable;

    function bidMarketItem(uint256 tokenId) external payable;

    function getItemBidsLength() external view returns (uint256);

    function acceptBid(uint256 tokenId, uint256 bidId) external payable;

    function rejectBid(uint256 tokenId, uint256 bidId) external payable;

    function getBalance() external view returns (uint256);

    receive() external payable;
}