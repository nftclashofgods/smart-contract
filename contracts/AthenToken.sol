// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PancakeSwap/IPancakeFactory.sol";
import "./PancakeSwap/IPancakeRouter02.sol";
import "./BPContract.sol";

contract AthenToken is ERC20Burnable, Ownable {
    using SafeMath for uint256;
	uint256 constant MAX_INT_TYPE = type(uint256).max;
    uint256 public maxSupply = 100 * 10**6 * 10**18;

    uint256 public sellFeeRate = 5;		
	address public backupAddress;

	address public PancakeSwapV2Pair;
	IPancakeRouter02 public PancakeRouter;

	BPContract public BotProtection;
	bool public bpEnabled;
	bool public BPDisabledForever = false;

	mapping(address => bool) private feeFreeList;	

    constructor() ERC20("Clash of Gods Token", "ATHEN") {
		_mint(msg.sender, maxSupply);
	}

    function _transfer(
		address sender,
		address recipient,
		uint256 amount
	) internal virtual override {		
		uint256 transferFeeRate;

		if (bpEnabled && !BPDisabledForever){
 			BotProtection.protect(sender, recipient, amount);
 		}

		if (!feeFreeList[sender] || !feeFreeList[recipient]) {
			if (recipient == PancakeSwapV2Pair) { // receiver is pancakeSwapV2Pair mean this is a "sell" tx
				transferFeeRate = sellFeeRate;
			}
		}
		
		if (transferFeeRate > 0) {
			uint256 sellFee = amount.mul(transferFeeRate).div(100);            
			super._transfer(sender, address(this), sellFee); // TransferFee			
            amount = amount.sub(sellFee);
		}

		super._transfer(sender, recipient, amount);
	}

	function initializePancakeRouter(address pancakeRouterAddress) external onlyOwner {
		IPancakeRouter02 pancakeRouter = IPancakeRouter02(pancakeRouterAddress);
		PancakeSwapV2Pair = IPancakeFactory(pancakeRouter.factory())
								.createPair(address(this), pancakeRouter.WETH());

		PancakeRouter = pancakeRouter;
	}

	function setBPAddress(address _bp) external onlyOwner {
 		require(address(BotProtection) == address(0), "Can only be initialized once");
 		BotProtection = BPContract(_bp);
	}

	function setBpEnabled(bool _enabled) external onlyOwner {
 		bpEnabled = _enabled;
	}

	function setBotProtectionDisableForever() external onlyOwner{
 		require(BPDisabledForever == false);
 		BPDisabledForever = true;
	}


	function setBackupAddress(address _backupAddress) external onlyOwner {
		backupAddress = _backupAddress;	
		emit ChangeBackupAddress(backupAddress);	
	}

	function addWhiteListAddresses(address[] calldata targets) external onlyOwner {
		for (uint256 i = 0; i < targets.length; i++) {		
			require(!feeFreeList[targets[i]]);
			
			feeFreeList[targets[i]] = true;
			emit UpdateWhiteList(targets[i], 1);
		}
	}

	function removeWhiteListAddresses(address[] calldata targets) external onlyOwner {
		for (uint256 i = 0; i < targets.length; i++) {		
			require(feeFreeList[targets[i]]);
			
			feeFreeList[targets[i]] = false;
			emit UpdateWhiteList(targets[i], 0);
		}
	}
	
	function swapTokens(uint256 amount) external onlyOwner returns (bool succeed) {
		require(amount < balanceOf(address(this)), "not enough balance");		
		return swapTokensForBNB(amount);
	}

	function swapTokensForBNB(uint256 tokenAmount) private returns (bool succeed) {
		// generate the pancakeSwap pair
		address[] memory path = new address[](2);
		path[0] = address(this);
		path[1] = PancakeRouter.WETH();

		if (allowance(address(this), address(PancakeRouter)) < tokenAmount) {
			_approve(address(this), address(PancakeRouter), MAX_INT_TYPE);
		}
		try PancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
			tokenAmount,
			0, // accept any amount of BNB
			path,
			backupAddress,
			block.timestamp
		) {
			return true;
		}
		catch Error(string memory /*reason*/) {
			return false;
		}
	}

	event UpdateWhiteList(address indexed target, uint8 isAdd);	
	event ChangeBackupAddress(address indexed target);
}