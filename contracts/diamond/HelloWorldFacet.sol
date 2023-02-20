pragma solidity ^0.8.7;


contract HelloWorldFacet {
	function sayHello() public pure returns(string memory){
		return "hello world";
	}
}