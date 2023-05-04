// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;


// 合约与外部的组件交互，主要有两种：
// 一种是允许外部主动调用过来的，如entrypoint, socialrecovery，这种可以叫做module。
// 另一种是合约在特定的地方主动调用外部的，主要有guard，execBefore，execAfter，fallback，以及升级的时候的delegatecall，这种可以叫做plugin或者hook。

// 我们合约把这两种方式管理好就可以了？其实和gnosis-safe合约很像，主要是在管理module和plugin的时候要加时间锁或者白名单的控制。

// Module: contract that can directly call soulwalet's function (exec(), setOwners()). For example SocialRecoveryModule, EntryPoint
// Plugin/Hook: contract that is called by soulwallet like a hook. For example, transaction guard, delegatecall to Upgrader Contract

contract ExampleWallet is FallbackManager, ValidateGuardManager, DelegateCallManager, ExecuteGuardManager {
    mapping (address => bool) authorizedModule;

    function validateUserOp(userOp, userOpHash, missingAccountFunds);
    

    // require only from authorize modules
    function exec() external {
        require(authorizedModule[msg.sender]);

        executeGuard.beforeExec();

        cal();
        
        executeGuard.afterExec();
    }
    function execBatch() {
        require(authorizedModule[msg.sender]);
    }
    function setOwners(address[] toAdd, address[] toRemove) {
        require(authorizedModule[msg.sender]);
    }

    // require only from authorize modules
    // require call to specific address
    function execDelegateCall(to, data) {
        require(authorizedModule[msg.sender]);
        require(permitDelegateCall[to]);
        delegatecall();
    }

    fallback() {
        fallbackManager.call();
    }
}