pragma solidity ^0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBidToken.sol";

contract Auction is Ownable {
    enum StatusBid {
        UNDEFINE,
        TRADE,
        BUY
    }

    struct Bid {
        uint256 endTime;
        uint24 minAmountforBid;
        address NFT;
        StatusBid status;
    }

    struct Winner {
        address winerBid;
        uint256 highAmountBid;
    }
    event CreateBid(uint256 id, address NFT, uint256 time, uint256 minAmount);
    event CloseBid(uint256 id, address winner);
    event PlaceForBet(address account, uint256 amount, uint256 id);
    event AddMemberForBid(address guest, uint256 amount);
    event BuyBidToken(
        address account,
        uint256 feeAmount,
        uint256 amountBuyToken
    );

    address[] owners;
    uint256 immutable minAmount;
    uint256 idBid;

    address bidToken;
    uint8 platformFee;

    uint256 allFee;
    uint256 allPayToMember;

    uint256 priceToBid = 0.3 ether;
    mapping(uint256 => Bid) bids;
    mapping(uint256 => Winner) winnerBid;
    mapping(address => bool) memberList;
    mapping(address => bool) isOwner;
    mapping(address => mapping(uint256 => uint256)) bidAmount;

    modifier onlyOwners() {
        require(isOwner[msg.sender], "Council: You are't owner");
        _;
    }

    modifier onlyMembers() {
        require(memberList[msg.sender], "Council: You are't member");
        _;
    }

    constructor(
        address bidToken_,
        uint256 minAmount_,
        uint8 platformFee_,
        address[] memory owners_
    ) {
        bidToken = bidToken_;
        minAmount = minAmount_;
        //fee to platform
        platformFee = platformFee_;

        for (uint256 i = 0; i < owners_.length; i++) {
            address owner = owners_[i];

            require(owner != address(0), "Council: Invalid owner");
            require(!isOwner[owner], "Council: Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
    }

    function createBid(
        address NFT,
        uint256 endTime_,
        uint24 minAmount_
    ) external onlyOwners {
        Bid storage bid = bids[idBid];
        bid.NFT = NFT;
        bid.endTime = block.timestamp + endTime_;
        bid.minAmountforBid = minAmount_;
        bid.status = StatusBid.TRADE;
        ++idBid;
        emit CreateBid(idBid, NFT, block.timestamp + endTime_, minAmount_);
    }

    function closeBid(uint256 id) external onlyOwners {
        Bid storage bid = bids[id];
        require(bid.status == StatusBid.TRADE, "Bid is buy");
        bid.status = StatusBid.BUY;
        Winner storage win = winnerBid[id];
        emit CloseBid(id, win.winerBid);
    }

    function placeBet(uint256 amount, uint256 id) external onlyMembers {
        Bid storage bid = bids[id];
        require(bid.status == StatusBid.TRADE, "Bid is buy");

        require(amount >= bid.minAmountforBid, "Your amount is less");
        require(
            IBidToken(bidToken).balanceOf(msg.sender) >= amount,
            "You don't have a lot of tokens"
        );
        bidAmount[msg.sender][id] += amount;
        Winner storage win = winnerBid[id];
        if (amount > win.highAmountBid) {
            win.highAmountBid = amount;
            win.winerBid = msg.sender;
        }
        emit PlaceForBet(msg.sender, amount, id);
    }

    function addMemberForBid(address guest) external payable {
        require(msg.value >= priceToBid, "Your amount is small");
        allPayToMember += msg.value;
        memberList[guest] = true;
        emit AddMemberForBid(guest, msg.value);
    }

    function buyBidToken() external payable onlyMembers {
        require(
            msg.value >= minAmount,
            "Auction: Invested amount is too small"
        );
        uint256 feeAmount = _calcPercent(msg.value, platformFee);
        allFee += feeAmount;
        uint256 cleanAmount = msg.value - feeAmount;
        uint256 amountBuyToken = cleanAmount / IBidToken(bidToken).getPrice();
        IBidToken(bidToken).transferFrom(bidToken, msg.sender, amountBuyToken);
        emit BuyBidToken(msg.sender, feeAmount, amountBuyToken);
    }

    function _calcPercent(uint256 value, uint256 percent)
        internal
        pure
        returns (uint256 res)
    {
        return ((percent * value) / (100));
    }
}