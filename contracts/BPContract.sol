// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

abstract contract BPContract {
	// Views
	function protect(
		address sender,
		address receiver,
		uint256 amount
	) external virtual;
}