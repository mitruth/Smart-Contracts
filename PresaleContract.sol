// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PresaleEcobonus is ReentrancyGuard, Ownable, Pausable {
    struct User {
        //tokens bought for a user
        uint256 tokens_amount;
        //deposited usdt for a user
        uint256 usdt_deposited;
        //if a user has claimed or not
        bool has_claimed;
    }

    struct Round {
        //wallet getting the money
        address payable wallet;
        //token amount bought with 1 usdt
        uint256 usdt_to_token_rate;
        //usdt + eth in usdt
        uint256 usdt_round_raised;
        //usdt + eth in usdt
        uint256 usdt_round_cap;
    }

    IERC20 public usdt_interface;
    IERC20 public token_interface;
    AggregatorV3Interface internal price_feed;

    mapping(address => User) public users_list;
    Round[] public round_list;

    uint8 public current_round_index;
    bool public presale_ended;

    event Deposit(address indexed _user_wallet, uint indexed _pay_method, uint _user_usdt_trans, uint _user_tokens_trans);

    constructor(
        address _oracle, 
        address _usdt, 
        address _token,
        address payable _wallet,
        uint256 _usdt_to_token_rate,
        uint256 _usdt_round_cap
    ) {
        usdt_interface = IERC20(_usdt);
        token_interface = IERC20(_token);
        price_feed = AggregatorV3Interface(_oracle);

        current_round_index = 0;
        presale_ended = false;

        round_list.push(
            Round(_wallet, _usdt_to_token_rate, 0, _usdt_round_cap * (10**6))
        );
    }

    modifier canPurchase(address user, uint256 amount) {
        require(user != address(0), "PURCHASE ERROR: User address is null!");
        require(amount > 0, "PURCHASE ERROR: Amount is 0!");
        require(presale_ended == false, "PURCHASE ERROR: Presale has ended!");
        _;
    }

    function get_eth_in_usdt() internal view returns (uint256) {
        (, int256 price, , , ) = price_feed.latestRoundData();
        price = price * 1e10;
        return uint256(price);
    }

    function buy_with_usdt(uint256 _amount)
        external
        nonReentrant
        whenNotPaused
        canPurchase(_msgSender(), _amount)
        returns (bool)
    {
        uint256 amount_in_usdt = _amount;
        require(
            round_list[current_round_index].usdt_round_raised + amount_in_usdt <
                round_list[current_round_index].usdt_round_cap,
            "BUY ERROR : Too much money already deposited."
        );

        uint256 allowance = usdt_interface.allowance(msg.sender, address(this));

        require(_amount <= allowance, "BUY ERROR: Allowance is too small!");

        (bool success_receive, ) = address(usdt_interface).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                msg.sender,
                round_list[current_round_index].wallet,
                amount_in_usdt
            )
        );

        require(success_receive, "BUY ERROR: Transaction has failed!");

        uint256 amount_in_tokens = (amount_in_usdt *
            round_list[current_round_index].usdt_to_token_rate) * 1e12;

        users_list[_msgSender()].usdt_deposited += amount_in_usdt;
        users_list[_msgSender()].tokens_amount += amount_in_tokens;

        round_list[current_round_index].usdt_round_raised += amount_in_usdt;

        emit Deposit(_msgSender(), 3, amount_in_usdt, amount_in_tokens);

        return true;
    }

    
    function buy_with_eth()
        external
        payable
        nonReentrant
        whenNotPaused
        canPurchase(_msgSender(), msg.value)
        returns (bool)
    {
        uint256 amount_in_usdt = (msg.value * get_eth_in_usdt()) / 1e30;
        require(
            round_list[current_round_index].usdt_round_raised + amount_in_usdt <
                round_list[current_round_index].usdt_round_cap,
            "BUY ERROR : Too much money already deposited."
        );

        uint256 amount_in_tokens = (amount_in_usdt *
            round_list[current_round_index].usdt_to_token_rate) * 1e12;

        users_list[_msgSender()].usdt_deposited += amount_in_usdt;
        users_list[_msgSender()].tokens_amount += amount_in_tokens;

        round_list[current_round_index].usdt_round_raised += amount_in_usdt;

        (bool sent,) = round_list[current_round_index].wallet.call{value: msg.value}("");
        require(sent, "TRANSFER ERROR: Failed to send Ether");

        emit Deposit(_msgSender(), 1, amount_in_usdt, amount_in_tokens);

        return true;
    }

    function buy_with_eth_wert(address user)
        external
        payable
        nonReentrant
        whenNotPaused
        canPurchase(user, msg.value)
        returns (bool)
    {

        uint256 amount_in_usdt = (msg.value * get_eth_in_usdt()) / 1e30;
        require(
            round_list[current_round_index].usdt_round_raised + amount_in_usdt <
                round_list[current_round_index].usdt_round_cap,
            "BUY ERROR : Too much money already deposited."
        );

        uint256 amount_in_tokens = (amount_in_usdt *
            round_list[current_round_index].usdt_to_token_rate) * 1e12;

        users_list[user].usdt_deposited += amount_in_usdt;
        users_list[user].tokens_amount += amount_in_tokens;

        round_list[current_round_index].usdt_round_raised += amount_in_usdt;

        (bool sent,) = round_list[current_round_index].wallet.call{value: msg.value}("");
        require(sent, "TRANSFER ERROR: Failed to send Ether");

        emit Deposit(user, 2, amount_in_usdt, amount_in_tokens);

        return true;
    }

    function claim_tokens() external returns (bool) {
        require(presale_ended, "CLAIM ERROR : Presale has not ended!");
        require(
            users_list[_msgSender()].tokens_amount != 0,
            "CLAIM ERROR : User already claimed tokens!"
        );
        require(
            !users_list[_msgSender()].has_claimed,
            "CLAIM ERROR : User already claimed tokens"
        );

        uint256 tokens_to_claim = users_list[_msgSender()].tokens_amount;
        users_list[_msgSender()].tokens_amount = 0;
        users_list[_msgSender()].has_claimed = true;

        (bool success, ) = address(token_interface).call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                msg.sender,
                tokens_to_claim
            )
        );
        require(success, "CLAIM ERROR : Couldn't transfer tokens to client!");

        return true;
    }

    function start_next_round(
        address payable _wallet,
        uint256 _usdt_to_token_rate,
        uint256 _usdt_round_cap
    ) external onlyOwner {
        current_round_index = current_round_index + 1;

        round_list.push(
            Round(_wallet, _usdt_to_token_rate, 0, _usdt_round_cap * (10**6))
        );
    }

    function set_current_round(
        address payable _wallet,
        uint256 _usdt_to_token_rate,
        uint256 _usdt_round_cap
    ) external onlyOwner {
        round_list[current_round_index].wallet = _wallet;
        round_list[current_round_index]
            .usdt_to_token_rate = _usdt_to_token_rate;
        round_list[current_round_index].usdt_round_cap = _usdt_round_cap * (10**6);
    }

    function get_current_round()
        external
        view
        returns (
            address,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            round_list[current_round_index].wallet,
            round_list[current_round_index].usdt_to_token_rate,
            round_list[current_round_index].usdt_round_raised,
            round_list[current_round_index].usdt_round_cap
        );
    }

    function get_current_raised() external view returns (uint256) {
        return round_list[current_round_index].usdt_round_raised;
    }

    function end_presale() external onlyOwner {
        presale_ended = true;
    }

    function withdrawToken(address tokenContract, uint256 amount) external onlyOwner {
        IERC20(tokenContract).transfer(_msgSender(), amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
