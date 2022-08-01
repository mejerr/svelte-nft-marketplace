// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";
import "./NFT.sol";
import "./IMarketPlace.sol";

contract MarketPlace is Ownable, ReentrancyGuard, IMarketPlace {
    using Counters for Counters.Counter;

    Counters.Counter private _collectionId;
    Counters.Counter private _tokenIds;
    Counters.Counter private _bidIds;

    uint256 private lockedBidAmount = 0;
    uint256 private constant LISTING_FEE = 0.025 ether;
    uint256 private collectedListingFee = 0;
    NFT private immutable marketItemContract;

    mapping(uint256 => Collection) public collections;
    mapping(uint256 => MarketItem) public marketItems;
    mapping(uint256 => mapping(uint256 => Bid)) public itemBids;
    mapping(address => Creator) public creatorsInfo;

    uint256[] public collectionsIds;
    uint256[] public marketItemsIds;
    uint256[] public bidsIds;

    modifier onlyTokenOwner(uint256 tokenId) {
        require(
            marketItemContract.ownerOf(tokenId) == msg.sender,
            "Marketplace: token is not owned by you"
        );
        _;
    }

    modifier onlyTokenExists(uint256 tokenId) {
        require(
            marketItems[tokenId].tokenId == tokenId,
            "Marketplace: no such token"
        );
        _;
    }

    modifier onlyBidExists(uint256 tokenId, uint256 bidId) {
        require(
            itemBids[tokenId][bidId].bidId == bidId,
            "Marketplace: no such bid"
        );
        _;
    }

    modifier onlyValueEnough() {
        require(
            msg.value == LISTING_FEE,
            "Marketplace: price must be equal to listing price"
        );
        _;
    }

    modifier onlyForSale(uint256 tokenId) {
        require(
            marketItems[tokenId].status == TokenStatus.ForSale,
            "Marketplace: item is not for sale"
        );
        _;
    }

    constructor(address _marketItemAddress) {
        marketItemContract = NFT(_marketItemAddress);
    }

    /* Get listing fee */
    function getListingFee() external view virtual override returns (uint256) {
        return LISTING_FEE;
    }

    /* Get collected listing fee */
    function getCollectedListingFee()
        external
        view
        virtual
        override
        returns (uint256)
    {
        return collectedListingFee;
    }

    /* Transfers collected listing fees to owner */
    function transferListingFee()
        external
        payable
        virtual
        override
        onlyOwner
        nonReentrant
    {
        uint256 fee = collectedListingFee;
        collectedListingFee = 0;
        address(this).balance - fee;
        payable(msg.sender).transfer(fee);

        emit ListingFeeToOwner(collectedListingFee);
    }

    /* Change address owned username */
    function changeCreatorName(string calldata name) external virtual override {
        creatorsInfo[msg.sender].name = name;

        emit CreatorNameChanged(name, msg.sender);
    }

    /* Change address owned image */
    function changeCreatorImage(string calldata image)
        external
        virtual
        override
    {
        creatorsInfo[msg.sender].image = image;

        emit CreatorImageChanged(image, msg.sender);
    }

    /* Creates a collection of future NFTs */
    function createCollection(
        string calldata image,
        string calldata name,
        string calldata description
    ) external virtual override {
        _collectionId.increment();
        uint256 collectionId = _collectionId.current();

        collections[collectionId] = Collection(
            collectionId,
            name,
            description,
            msg.sender,
            image
        );

        collectionsIds.push(collectionId);

        emit CollectionCreated(collectionId, msg.sender);
    }

    /* Gets collection array length */
    function getCollectionLength() external view override returns (uint256) {
        return collectionsIds.length;
    }

    /* Mint new NFT token */
    function mintToken(
        string memory tokenURI,
        string calldata name,
        string calldata description,
        uint256 collectionId
    ) public payable virtual override nonReentrant {
        require(
            collections[collectionId].creator == msg.sender,
            "Marketplace: no collection of yours"
        );

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        marketItemContract.mint(msg.sender, newTokenId, tokenURI);

        marketItems[newTokenId] = MarketItem(
            newTokenId,
            name,
            description,
            0,
            collectionId,
            TokenStatus.Idle
        );

        marketItemsIds.push(newTokenId);

        emit TokenMinted(newTokenId, 0, collectionId);
    }

    /* Get items array length */
    function getMarketItemsLength()
        external
        view
        virtual
        override
        returns (uint256)
    {
        return marketItemsIds.length;
    }

    /* Create market sale */
    function createSale(uint256 tokenId, uint256 _price)
        external
        payable
        virtual
        override
        onlyTokenExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyValueEnough
        nonReentrant
    {
        collectedListingFee += msg.value;
        marketItems[tokenId].price = _price;
        marketItems[tokenId].status = TokenStatus.ForSale;

        emit CreateMarketSale(tokenId, _price);
    }

    /* Cancel market sale */
    function cancelSale(uint256 tokenId)
        external
        override
        onlyTokenExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyForSale(tokenId)
    {
        marketItems[tokenId].price = 0;
        marketItems[tokenId].status = TokenStatus.Idle;

        emit CancelMarketSale(tokenId);
    }

    /* Transfers ownership of the token as well as funds between parties */
    function buyMarketItem(uint256 tokenId)
        external
        payable
        virtual
        override
        onlyForSale(tokenId)
        nonReentrant
    {
        address tokenOwner = marketItemContract.ownerOf(tokenId);

        require(
            tokenOwner != msg.sender,
            "Marketplace: you can not buy your own item"
        );
        require(
            msg.value == marketItems[tokenId].price,
            "Marketplace: amount must be equal to the item listing price"
        );

        marketItems[tokenId].price = 0;
        marketItems[tokenId].status = TokenStatus.Idle;

        marketItemContract.transferFrom(tokenOwner, msg.sender, tokenId);
        payable(tokenOwner).transfer(msg.value);

        emit ItemBought(tokenId, msg.sender, tokenOwner, msg.value);
    }

    /* Adds bid for specific market item */
    function bidMarketItem(uint256 tokenId)
        external
        payable
        virtual
        override
        onlyTokenExists(tokenId)
        nonReentrant
    {
        require(msg.value > 0, "Marketplace: bid must be at least one wei");
        require(
            marketItemContract.ownerOf(tokenId) != msg.sender,
            "Marketplace: you can not bid your own item"
        );

        _bidIds.increment();
        uint256 newBidId = _bidIds.current();

        lockedBidAmount += msg.value;
        itemBids[tokenId][newBidId] = Bid(
            newBidId,
            msg.value,
            payable(msg.sender),
            BidStatus.Idle
        );

        bidsIds.push(newBidId);

        emit BidCreated(newBidId, msg.value, msg.sender);
    }

    /* Get bids array length */
    function getItemBidsLength() public view override returns (uint256) {
        return bidsIds.length;
    }

    /* Accepts bid from bidder for specific market item */
    function acceptBid(uint256 tokenId, uint256 bidId)
        external
        payable
        virtual
        override
        onlyTokenOwner(tokenId)
        onlyBidExists(tokenId, bidId)
        nonReentrant
    {
        address bidder = itemBids[tokenId][bidId].bidder;
        uint256 amount = itemBids[tokenId][bidId].amount;

        marketItems[tokenId].price = 0;
        marketItems[tokenId].status = TokenStatus.Idle;

        marketItemContract.transferFrom(msg.sender, bidder, tokenId);

        itemBids[tokenId][bidId].status = BidStatus.Accepted;
        lockedBidAmount -= amount;
        address(this).balance - amount;
        payable(msg.sender).transfer(amount);

        emit BidAccepted(tokenId, bidId, amount, bidder);
    }

    /* Cancels bid from bidder for specific market item */
    function rejectBid(uint256 tokenId, uint256 bidId)
        external
        payable
        override
        onlyTokenExists(tokenId)
        onlyBidExists(tokenId, bidId)
        nonReentrant
    {
        address bidder = itemBids[tokenId][bidId].bidder;
        uint256 amount = itemBids[tokenId][bidId].amount;

        lockedBidAmount -= amount;
        address(this).balance - amount;
        itemBids[tokenId][bidId].status = BidStatus.Rejected;
        payable(bidder).transfer(amount);

        emit BidCancelled(tokenId, bidId, msg.sender);
    }

    function getBalance() external view override returns (uint256) {
        return address(this).balance;
    }

    /* Receive money in the smart contract */
    receive() external payable virtual override {
        emit Deposit(msg.value);
    }
}
