// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

/*
    Voodoo Vault / 2022 / V10k.1

    Smart Contract that I wrote as web3/blockchain specialist for the Voodoo Vault team. Part of a multi version project which enables romanian artists to form a community and take part in the metaverse.

*/
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract VoodooVaultAniversaryEdition is ERC1155Burnable, Ownable {
    using Strings for uint256;
    using ECDSA for bytes32;

    uint256 private supply;

    uint256 public MAX_SUPPLY;
    uint256 public tokenIdToMint;
    uint256 public maxTokenID;

    string public constant NAME = "VOODOO VAULT ANIVERSARY EDITION";
    string public constant SYMBOL = "VVANVR";
    string private baseURI;

    bool public saleLive = false;
    bool public locked = false;

    mapping(address => bool) public salePurchasesOfWallet;

    constructor(
        string memory _baseURI
    ) ERC1155(_baseURI) {
        baseURI = _baseURI;
        MAX_SUPPLY = 500;
        tokenIdToMint = 0;
        maxTokenID = 0;
    }

    modifier notLocked {
        require(!locked, "Contract metadata is locked");
        _;
    }

    function buy() external {
        require(saleLive, "SALE CLOSED");
        require(supply + 1 <= MAX_SUPPLY, "MAX_MINT_ACHIEVED");
        require(!salePurchasesOfWallet[msg.sender], "MAX 1 TOKEN PER ADDRESS");

        supply += 1;
        salePurchasesOfWallet[msg.sender] = true;

        _mint(msg.sender, tokenIdToMint, 1, "");
    }

    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    function uri(uint256 id) public view override returns (string memory) {
        require(bytes(baseURI).length > 0, "BASE URI NOT SET");
        require(id <= maxTokenID, "TOKEN ID NON-EXISTENT");
        return string(abi.encodePacked(baseURI, Strings.toString(id)));
    }

    function totalSupply() public view returns (uint256) {
        return supply;
    }

    function setBaseUri(string calldata _baseURI) external onlyOwner notLocked{
        baseURI = _baseURI;
    }

    function changeSupply(uint256 newSupply, uint256 newId) external onlyOwner {
        require(newId <= maxTokenID + 1, "CANNOT INCREASE TOKEN TO MINT WITH MORE THAN 1");
        require(newSupply >= MAX_SUPPLY, "CANNOT SET NEW SUPPLY LOWER THAN PREVIOUS SUPPLY");
        MAX_SUPPLY = newSupply;
        tokenIdToMint = newId;
        if(newId > maxTokenID) {
            maxTokenID = newId;
        }
    }

    function lockMetadata() external onlyOwner {
        locked = true;
    }

    function toggleSaleStatus() external onlyOwner {
        saleLive = !saleLive;
    }
}