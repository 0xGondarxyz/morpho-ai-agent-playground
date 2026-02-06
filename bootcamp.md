Recon Logo

    Introduction
    Writing Invariant Tests
    1. Learn Invariant Testing
    2. Example Project
    3. Implementing Properties
    4. Optimizing Broken Properties
    5. Advanced Fuzzing Tips
    6. Chimera Framework
    7. Create Chimera App
    Bootcamp
    8. Intro to the Bootcamp
    9. Part 1 - Invariant Testing with Chimera Framework
    10. Part 2 - Multidimensional Invariant Tests
    11. Part 3 - Writing and Breaking Properties
    12. Part 4 - Liquity Governance Case Study
    Using Recon
    13. Getting Started
    14. Upgrading to Pro
    15. Building Handlers
    16. Running Jobs
    17. Recon Magic
    18. Recipes
    19. Alerts
    20. Campaigns
    21. Dynamic Replacement
    22. Governance Fuzzing
    23. Recon Tricks
    Free Recon Tools
    24. Recon Extension
    25. Medusa Log Scraper
    26. Echidna Log Scraper
    27. Handler Builder
    28. Bytecode Compare
    29. Bytecode To Interface
    30. Bytecode Static Deployment
    31. Bytecode Formatter
    32. String To Bytes
    33. OpenZeppelin Roles Scraper
    OSS Repos
    34. Chimera
    35. Create Chimera App
    36. Log Parser
    37. ABI to Invariants
    38. ABI to Mock
    39. Setup Helpers
    40. Properties Table
    41. ERC7540 Reusable Properties
    OpSec
    42. OpSec Resources
    Help
    43. Glossary

Recon Book
Part 1 - Invariant Testing with Chimera Framework

    For the recorded stream of this part of the bootcamp see here.

In this first part we're going to look at the Chimera Framework, what it is, why it exists and how we can use it to test a smart contract system using multiple different tools. By the end of part 1 you should be comfortable scaffolding a system and ensuring it has full coverage.

    This bootcamp is roughly based on the first three parts of the bootcamp streamed by Alex The Entreprenerd here though some of the implementation details have changed, however you can still use it to follow along if you prefer consuming content in a video format.

The Chimera Framework Contracts

The key idea behind the Chimera framework is to use the following contracts as a scaffolding for your test suite:

    Setup - where deployment configurations are located
    TargetFunctions - explicitly define all functions that should be called by the tool as part of state exploration
    Properties - used to explicitly define the properties to be tested
    BeforeAfter - used to track variables over time to define more complex properties
    CryticTester - the entrypoint from which a given tool will execute tests
    CryticToFoundry - used for debugging broken properties with Foundry

This scaffolding reduces the decisions you have to make about your test suite configuration so you can get to writing and breaking properties faster.

    For more details on how to use the above contracts checkout the Chimera Framework page.

The primary contracts we'll be looking at in this lesson are Setup and TargetFunctions.

In the Setup contract we're going to locate all of our deployment configuration. This can become very complex but for now all you need to think about is specifying how to deploy all the contracts of interest for our tool.

The TargetFunctions contract allows you to explicitly state all the functions that should be called as part of state exploration. For more complex codebases you'll generally have multiple sub-contracts which specify target functions for each of the contracts of interest in the system which you can inherit into TargetFunctions. Fundamentally, any time you're thinking about exploring state the handler for the state changing call should be located in TargetFunctions.
Getting Started

To follow along, you can clone this fork of the Morpho repository. We'll then see how to use the Recon Builder to add all the Chimera scaffolding for our contract of interest.

Our primary goals for this section are:

    setup - create the simplest setup possible that allows you to test all interesting state combinations
    coverage - understand how to read a coverage report and resolve coverage issues

Practical Implementation - Setting Up Morpho

Once you've cloned the Morpho repo locally you can make the following small changes to speed up compilation and test run time:

    disable via-ir in the foundry.toml configuration
    remove the bytecode_hash = "none" from the foundry.toml configuration (this interferes with coverage report generation in the fuzzer)
    delete the entire existing test folder

Our next step is going to be getting all the Chimera scaffolding added to our repo which we'll do using the Recon Extension because it's the fastest and simplest way.

    You can also generate your Chimera scaffolding without downloading the extension using the Recon Builder instead

After having downloaded the extension you'll need to build the project so it can recognize the contract ABIs that we want to scaffold:

Build Contracts

We can then select the contract for which we want to generate target functions for, in our case this will be the Morpho contract:

Selecting Targets

The UI additionally gives us the option to select which state-changing functions we'd like to scaffold by clicking the checkmark next to each. For our case we'll keep all the default selected target functions.

After scaffolding, all the Chimera Framework contracts will be added to a new test folder and fuzzer configuration files will be added to the root directory:

Scaffolding Added
Fail Mode and Catch Mode

The extension offers additional "modes" for target functions: fail mode and catch mode:

Test Modes In Extension

Fail mode will force an assertion failure after a call is successful. We use this for defining what we call canaries (tests that confirm if certain functions are not always reverting) because the assertion will only fail if the call to the target function completes successfully.

Catch mode is useful to add a test to the catch block with an assertion to determine when it reverts. This is a key mindset shift of invariant testing with Echidna and Medusa because they don't register a revert as a test failure and instead skip reverting calls. Test failures in these fuzzers therefore only occur via an assertion failure (unlike Foundry where a reverting call automatically causes the test to fail).

This is important to note because without it you could end up excluding reverting cases which can reveal interesting states that could help find edge cases.

    If you're ever using Foundry to fuzz instead of Echidna or Medusa, you should disable the fail_on_revert parameter in your Foundry config to have similar behavior to the other fuzzers and allow tests written for them to be checked in the same way.

Setup

Generally you should aim to make the Setup contract as simple as possible, this helps reduce the number of assumptions made and also makes it simpler for collaborators to understand the initial state that the fuzzer starts from.

    If you used the Recon Builder for scaffolding you'll most likely have to spend some time resolving compilation errors due to incorrect imports because it isn't capable of automatically resolving these in the same way that the extension does.

In our case, because of the relative simplicity of the contract that we're deploying in our test suite we can just check the constructor arguments of the Morpho contract to determine what we need to deploy it:

contract Morpho is IMorphoStaticTyping {
...

    /// @param newOwner The new owner of the contract.
    constructor(address newOwner) {
        require(newOwner != address(0), ErrorsLib.ZERO_ADDRESS);

        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this)));
        owner = newOwner;

        emit EventsLib.SetOwner(newOwner);
    }

    ...

}

from which we can see that we simply need to pass in an owner for the deployed contract.

We can therefore modify our Setup contract accordingly so that it deploys the Morpho contract with address(this) (the default actor that we use as our admin) set as the owner of the contract:

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
Morpho morpho;

    function setup() internal virtual override {
        morpho = new Morpho(_getActor());
    }

    ...

}

We now have the contract which we can call target functions on deployed and we can now run the fuzzer!
Aside: How We Can Reuse Tests

Because we only implemented our deployments in a single setup function this can be inherited and called in the CryticTester contract:

contract CryticTester is TargetFunctions, CryticAsserts {
constructor() payable {
setup();
}
}

to allow us to test with Echidna or Medusa and also inherited in the CryticToFoundry contract to be tested with Foundry, Halmos and Kontrol:

contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
function setUp() public {
setup();
}
}

This gives us one of the primary benefits of using the Chimera Framework: if your project compiles in Foundry, it will work in any of the above mentioned tools automatically.
Running Your First Fuzzing Campaign

At this point, we've achieved compilation and our next step will simply be to figure out how far this allows the fuzzer to get in terms of line coverage over our contract of interest.

Before running you'll need to make sure you have Medusa downloaded on your local machine.

With Medusa downloaded you can use the Fuzz with Medusa button from the Recon Cockpit section of the Recon extension to start your fuzzing campaign:

Run Medusa Button

    You can also run Medusa using medusa fuzz from the root of your project directory

We'll run the fuzzer for 10-15 minutes then stop the execution (using the cancel button from the Recon Cockpit or ctrl + c from the CLI) to analyze the results.
Understanding Fuzzer Output

From the output logs from Medusa we can see that its entrypoint into our created test scaffolding is the CryticTester contract:

⇾ [PASSED] Assertion Test: CryticTester.add_new_asset(uint8)
⇾ [PASSED] Assertion Test: CryticTester.asset_approve(address,uint128)
⇾ [PASSED] Assertion Test: CryticTester.asset_mint(address,uint128)
⇾ [PASSED] Assertion Test: CryticTester.morpho_accrueInterest((address,address,address,address,uint256))
⇾ [PASSED] Assertion Test: CryticTester.morpho_borrow((address,address,address,address,uint256),uint256,uint256,address,address)
⇾ [PASSED] Assertion Test: CryticTester.morpho_createMarket((address,address,address,address,uint256))
⇾ [PASSED] Assertion Test: CryticTester.morpho_enableIrm(address)
⇾ [PASSED] Assertion Test: CryticTester.morpho_enableLltv(uint256)
⇾ [PASSED] Assertion Test: CryticTester.morpho_flashLoan(address,uint256,bytes)
⇾ [PASSED] Assertion Test: CryticTester.morpho_liquidate((address,address,address,address,uint256),address,uint256,uint256,bytes)
⇾ [PASSED] Assertion Test: CryticTester.morpho_repay((address,address,address,address,uint256),uint256,uint256,address,bytes)
⇾ [PASSED] Assertion Test: CryticTester.morpho_setAuthorization(address,bool)
⇾ [PASSED] Assertion Test: CryticTester.morpho_setAuthorizationWithSig((address,address,bool,uint256,uint256),(uint8,bytes32,bytes32))
⇾ [PASSED] Assertion Test: CryticTester.morpho_setFee((address,address,address,address,uint256),uint256)
⇾ [PASSED] Assertion Test: CryticTester.morpho_setFeeRecipient(address)
⇾ [PASSED] Assertion Test: CryticTester.morpho_setOwner(address)
⇾ [PASSED] Assertion Test: CryticTester.morpho_supply((address,address,address,address,uint256),uint256,uint256,address,bytes)
⇾ [PASSED] Assertion Test: CryticTester.morpho_supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)
⇾ [PASSED] Assertion Test: CryticTester.morpho_withdraw((address,address,address,address,uint256),uint256,uint256,address,address)
⇾ [PASSED] Assertion Test: CryticTester.morpho_withdrawCollateral((address,address,address,address,uint256),uint256,address,address)
⇾ [PASSED] Assertion Test: CryticTester.switch_asset(uint256)
⇾ [PASSED] Assertion Test: CryticTester.switchActor(uint256)

Which allows it to call all of the functions defined on our TargetFunctions contract (which in this case it inherits from MorphoTargets) in a random order with random values passed in.

    The additional functions called in the above logs are defined on the ManagersTargets which provide utilities for modifying the currently used actor (via the ActorManager) and admin (via the AssetManager) in the setup.

After running the fuzzer, it also generates a corpus which is a set of call sequences that allowed the fuzzer to expand line coverage:

Coverage Sequences

This will make it so that previous runs don't need to only explore random inputs each time and the fuzzer will be able to use inputs and call sequences that it found that expand coverage to guide its fuzzing process and add mutations (modifications) to them to attempt to unlock new coverage or break a property. You can think of the corpus as the fuzzer's memory which allows it to retrace its previous steps when it starts again.

    If you modify the interface of your target function handlers you should delete your existing corpus and allow the fuzzer to generate a new one, otherwise it will make calls using the previous sequences which may no longer be valid and prevent proper state space exploration.

Understanding Coverage Reports

After stopping Medusa it will also generate a coverage report (Chimera comes preconfigured to ensure that Medusa and Echidna always generate a coverage report) which is an HTML file that displays all the code from your project highlighting in green: lines which the fuzzer reached and in red: lines that the fuzzer didn't reach during testing.

Initial Morpho Coverage

The coverage report is one of the most vital insights in stateful fuzzing because without it, you're blind to what the fuzzer is actually doing.
Debugging Failed Properties

Now we'll add a simple assertion that always evaluates to false (canary property) to one of our target function handlers to see how the fuzzer outputs breaking call sequences for us:

    function morpho_setOwner(address newOwner) public asActor {
        morpho.setOwner(newOwner);
        t(false, "forced failure");
    }

Using this we can then run Medusa again and see that it generates a broken property reproducer call sequence for us:

⇾ [FAILED] Assertion Test: CryticTester.morpho_setOwner(address)
Test for method "CryticTester.morpho_setOwner(address)" resulted in an assertion failure after the following call sequence:
[Call Sequence]

1. CryticTester.morpho_setOwner(address)(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D) (block=29062, time=319825, gas=12500000, gasprice=1, value=0, sender=0x30000)
   [Execution Trace]
   => [call] CryticTester.morpho_setOwner(address)(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D) (addr=0x7D8CB8F412B3ee9AC79558791333F41d2b1ccDAC, value=0, sender=0x30000)
   => [call] StdCheats.prank(address)(0x7D8CB8F412B3ee9AC79558791333F41d2b1ccDAC) (addr=0x7109709ECfa91a80626fF3989D68f67F5b1DD12D, value=0, sender=0x7D8CB8F412B3ee9AC79558791333F41d2b1ccDAC)
   => [return ()]
   => [call] <unresolved contract>.<unresolved method>(msg_data=13af40350000000000000000000000007109709ecfa91a80626ff3989d68f67f5b1dd12d) (addr=0xA5668d1a670C8e192B4ef3F2d47232bAf287E2cF, value=0, sender=0x7D8CB8F412B3ee9AC79558791333F41d2b1ccDAC)
   => [event] SetOwner(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D)
   => [return]
   => [event] Log("forced failure")
   => [panic: assertion failed]

If you ran the fuzzer with the extension, it will give you the option to automatically add the generated reproducer unit test for this broken property to the CryticToFoundry contract:

    // forge test --match-test test_morpho_setOwner_uzpq -vvv
    function test_morpho_setOwner_uzpq() public {
       vm.roll(2);
       vm.warp(2);
       morpho_setOwner(0x0000000000000000000000000000000000000000);
    }

    If you ran the fuzzer via the CLI you can copy and paste the logs into this tool to generate a Foundry unit test

This will be key once we start to break nontrivial properties because it gives us a much faster feedback loop to debug them.
Initital Coverage Analysis

If we look more closely at the Morpho contract which we're targeting with our TargetFunctions we can see from the 28% in our coverage report that our target functions are only allowing us to reach minimal exploration of possible states:

Morpho Coverage Detailed

If we look at the coverage on our TargetFunctions directly however we see that we have 100% coverage and all the lines show up highlighted in green:

Target Functions Coverage

This is an indication to us that the calls to the target function handlers themselves are initially successful but once it reaches the actual function in the Morpho contract it reverts.
Understanding Morpho

Before we move on to looking at techniques that will allow us to increase coverage on the Morpho contract it'll help to have a bit of background on what Morpho is and how it works.

Morpho is a noncustodial lending protocol that functions as a lending marketplace where users can supply assets to earn interest and borrow against collateral.

The protocol uses a singleton architecture where all lending markets exist within a single contract, with each market defined by five parameters: loan token, collateral token, oracle, interest rate model, and loan-to-value ratio. It implements share-based accounting, supports permissionless market creation and includes liquidation mechanisms to maintain solvency.
Creating Mock Contracts

Now with a better understanding of Morpho we can see that for it to allow any user operations such as borrowing and lending it first needs a market to be created and for this we need an Interest Rate Model (IRM) contract which calculates dynamic borrow rates for Morpho markets based on utilization and can be set by an admin using the enableIrm function:

    function enableIrm(address irm) external onlyOwner {
        require(!isIrmEnabled[irm], ErrorsLib.ALREADY_SET);

        isIrmEnabled[irm] = true;

        emit EventsLib.EnableIrm(irm);
    }

Since the IRM can be any contract that implements the IIRM interface and there's none in the existing Morpho repo, we'll need to create a mock so that we can simulate its behavior which will allow us to achieve our short-term goal of coverage for now. If we find that the actual behavior of the IRM is interesting for any of the properties we want to test, we can later replace this with a more realistic implementation.

The Recon Extension allows automatically generating mocks for a contract by right-clicking it and selecting the Generate Solidity Mock option, but in our case since there's no existing instance of the IRM contract, we'll have to manually create our own as follows:

import {MarketParams, Market} from "src/interfaces/IMorpho.sol";

contract MockIRM {
uint256 internal \_borrowRate;

    function setBorrowRate(uint256 newBorrowRate) external {
        _borrowRate = newBorrowRate;
    }

    function borrowRate(MarketParams memory marketParams, Market memory market) public view returns (uint256) {
        return _borrowRate;
    }

    function borrowRateView(MarketParams memory marketParams, Market memory market) public view returns (uint256) {
        return borrowRate(marketParams, market);
    }

}

Our mock simply exposes functions for setting and getting the \_borrowRate because these are the functions defined in the IIRM interface. We'll then expose a target function that calls the setBorrowRate function which allows the fuzzer to modify the borrow rate randomly.

Now the next contract we'll need for creating a market is the oracle for setting the price of the underlying asset. Looking at the existing OracleMock in the Morpho repo we can see that it's sufficient for our case:

contract OracleMock is IOracle {
uint256 public price;

    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }

}

Now we just need to deploy all of these mocks in our setup:

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
Morpho morpho;

    // Mocks
    MockIRM irm;
    OracleMock oracle;

    /// === Setup === ///
    function setup() internal virtual override {
        // Deploy Morpho
        morpho = new Morpho(_getActor());

        // Deploy Mocks
        irm = new MockIRM();
        oracle = new OracleMock();

        // Deploy assets
        _newAsset(18); // asset
        _newAsset(18); // liability
    }

}

In the above we use the \_newAsset function exposed by the AssetManager to deploy a new asset which we can fetch using the \_getAsset() function.

    We introduced the AssetManager and ActorManager in V2 of Create Chimera App because the majority of setups will require multiple addresses to perform calls and use tokens in some way. Since our framework implicitly overrides the use of different senders via the fuzzer, the ActorManager allows us to replicate the normal behavior of having multiple senders using the asActor modifier. Similarly, tracking deployed tokens for checking properties or clamping previously required implementing unique configurations in the Setup contract, so we've abstracted this into the AssetManager to standardize the process and prevent needing to reimplement it each time.

Market Creation and Handler Implementation

Now to continue the fixes to our setup we'll need to register a market in the Morpho contract :

// Add import for MarketParams
import {Morpho, MarketParams} from "src/Morpho.sol";

And then we can register it by adding the following to our setup:

    function setup() internal virtual override {
        // Deploy Morpho
        morpho = new Morpho(_getActor());

        // Deploy Mocks
        irm = new MockIRM();
        oracle = new OracleMock();

        // Deploy assets
        _newAsset(18); // asset
        _newAsset(18); // liability

        // Create the market
        morpho.enableIrm(address(irm));
        morpho.enableLltv(8e17);

        address[] memory assets = _getAssets();
        MarketParams memory marketParams = MarketParams({
            loanToken: assets[1],
            collateralToken: assets[0],
            oracle: address(oracle),
            irm: address(irm),
            lltv: 8e17
        });
        morpho.createMarket(marketParams);
    }

It's important to note that this setup only allows us to test one market with the configurations we've added above, whereas if we want to truly be sure that we're testing all possibilities, we could use what we've termed as dynamic deployment to allow the fuzzer to deploy multiple markets with different configurations (we cover this in part 2).

We can then make a further simplifying assumption that will work as a form of clamping to allow us to get line coverage faster by storing the marketParams variable as a storage variable:

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
...

    MarketParams marketParams;

    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        ...

        address[] memory assets = _getAssets();
        marketParams = MarketParams({
            loanToken: assets[1],
            collateralToken: assets[0],
            oracle: address(oracle),
            irm: address(irm),
            lltv: 8e17
        });
        morpho.createMarket(marketParams);
    }

which then allows us to pass it directly into our target functions by deleting the input parameter for marketParams and using the storage variable from the setup instead:

abstract contract MorphoTargets is
BaseTargetFunctions,
Properties
{
function morpho_accrueInterest() public asActor {
morpho.accrueInterest(marketParams);
}

    function morpho_borrow(uint256 assets, uint256 shares, address onBehalf, address receiver) public asActor {
        morpho.borrow(marketParams, assets, shares, onBehalf, receiver);
    }

    function morpho_createMarket() public asActor {
        morpho.createMarket(marketParams);
    }

    // Note: remove from ALL functions the parameter MarketParams marketParams so that it is used the storage var
    ...

}

    The asActor modifier explicitly uses the currently set actor returned by _getActor() to call the handler functions, whereas the asAdmin modifier uses the default admin actor (address(this)). In the above setup we only have the admin actor added to the actor tracking array but we use the asActor address to indicate that these are functions that are expected to be called by any normal user. Only target functions expected to be called by privileged users should use the asAdmin modifier.

This helps us get to coverage over the lines of interest faster because instead of the fuzzer trying all possible inputs for the MarketParams struct, it uses the marketParams from the setup to ensure it always targets the correct market.
Asset and Token Setup

At this point we also need to mint the tokens we're using in the system to our actors and approve the Morpho contract to spend them:

import {MockERC20} from "@recon/MockERC20.sol"; // import Recon MockERC20

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
...

    function setup() internal virtual override {
        ...

        _setupAssetsAndApprovals();

        address[] memory assets = _getAssets();
        marketParams = MarketParams({
            loanToken: assets[1],
            collateralToken: assets[0],
            oracle: address(oracle),
            irm: address(irm),
            lltv: 8e17
        });
        morpho.createMarket(marketParams);
    }

    function _setupAssetsAndApprovals() internal {
        address[] memory actors = _getActors();
        uint256 amount = type(uint88).max;

        // Process each asset separately to reduce stack depth
        for (uint256 assetIndex = 0; assetIndex < _getAssets().length; assetIndex++) {
            address asset = _getAssets()[assetIndex];

            // Mint to actors
            for (uint256 i = 0; i < actors.length; i++) {
                vm.prank(actors[i]);
                MockERC20(asset).mint(actors[i], amount);
            }

            // Approve to morpho
            for (uint256 i = 0; i < actors.length; i++) {
                vm.prank(actors[i]);
                MockERC20(asset).approve(address(morpho), type(uint88).max);
            }
        }
    }

The \_setupAssetsAndApprovals function allows us to mint the deployed assets to the actors (handled by the ActorManager) and approves it to the deployed Morpho contract. Note that we mint type(uint88).max to each user because it's a sufficiently large amount that allows us to realistically test for overflow scenarios.
Testing Your Setup

Now to ensure that our setup doesn't cause the fuzzer to revert before executing any tests we can run the default test_crytic function in CryticToFoundry which is an empty test that will just call the setup function, this will confirm that our next run of the fuzzer will actually be able to start state exploration:

Ran 1 test for test/recon/CryticToFoundry.sol:CryticToFoundry
[PASS] test_crytic() (gas: 238)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 6.46ms (557.00µs CPU time)

Testing Token Interactions

We can also create a simple unit test to confirm that we can successfully supply the tokens minted above to the system as a user:

    function test_crytic() public {
        // testing supplying assets to a market as the default actor (address(this))
        morpho_supply(1e18, 0, _getActor(), hex"");
    }

which, if we run with forge test --match-test test_crytic -vvvv --decode-internal, will allow us to see how many shares we get minted:

    │   ├─ emit Supply(id: 0x5914fb876807b8cd7b8bc0c11b4d54357a97de46aae0fbdfd649dd8190ef99eb, caller: CryticToFoundry: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], onBehalf: CryticToFoundry: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], assets: 1000000000000000000 [1e18], shares: 1000000000000000000000000 [1e24])
    │   ├─ [38795] SafeTransferLib::safeTransferFrom(<unknown>, 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f, 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, 1136628940260574992893479910319181283093952727985 [1.136e48])
    │   │   ├─ [34954] MockERC20::transferFrom(CryticToFoundry: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], Morpho: [0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f], 1000000000000000000 [1e18])
    │   │   │   ├─ emit Transfer(from: CryticToFoundry: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], to: Morpho: [0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f], value: 1000000000000000000 [1e18])
    │   │   │   └─ ← [Return] true
    │   │   └─ ←
    │   └─ ← [Return] 1000000000000000000 [1e18], 1000000000000000000000000 [1e24]
    └─ ← [Return]

showing that we received 1e24 shares for the 1e18 assets deposited.

If we then expand our test to see if we can supply collateral against which a user can borrow:

    function test_crytic() public {
        morpho_supply(1e18, 0, _getActor(), hex"");// testing supplying assets to a market as the default actor (address(this))
        morpho_supplyCollateral(1e18, _getActor(), hex"");
    }

we see that it also succeeds, so we have confirmed that the fuzzer is also able to execute these basic user interactions.
Advanced Handler Patterns

At this point we know that we can get coverage over certain lines but we know that certain parameters still have a very large set of possible input values which may not allow them to be successfully covered by the fuzzer in a reasonable amount of time, so we can start to apply some simple clamping.
Clamped Handlers

We'll start with the morpho_supply function we tested above:

contract Morpho is IMorphoStaticTyping {

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256) {
        ...
    }

}

Since we only want one of our actors (see ActorManager for more details on the actor setup) in the system to receive shares and the data parameter can be any arbitrary bytes value we can clamp all the values except assets. We can follow a similar approach for the supplyCollateral function:

abstract contract MorphoTargets is
BaseTargetFunctions,
Properties
{
function morpho_supply_clamped(uint256 assets) public {
morpho_supply(assets, 0, \_getActor(), hex"");
}

    function morpho_supplyCollateral_clamped(uint256 assets) public {
        morpho_supplyCollateral(assets, _getActor(), hex"");
    }

}

Note that clamped handlers should always call the unclamped handlers; this ensures that you don't overly restrict the fuzzer from exploring all possible states because it can still explore unclamped values as well. Additionally, this ensures that when you add inlined tests or variable tracking to the unclamped handlers, the assertions are always checked and variable tracking is updated for either function call.

Now that we have clamped handlers, we can significantly increase the speed with which we can cover otherwise hard to reach lines.

We can then replace our existing calls in the test_crytic test with the clamped handlers and add an additional call to morpho_borrow to check if we can successfully borrow assets from the Morpho contract:

    function test_crytic() public {
        morpho_supply_clamped(1e18);
        morpho_supplyCollateral(1e18, _getActor(), hex"");

        morpho_borrow(1e18, 0, _getActor(), _getActor());
    }

Troubleshooting Coverage Issues

After running the test we see that the call to morpho_borrow fails because of insufficient collateral:

[FAIL: insufficient collateral] test_crytic() (gas: 215689)
Suite result: FAILED. 0 passed; 1 failed; 0 skipped; finished in 6.57ms (761.17µs CPU time)

Looking at the Morpho implementation we see this error originates in the \_isHealthy check in Morpho:

    function _isHealthy(MarketParams memory marketParams, Id id, address borrower, uint256 collateralPrice)
        internal
        view
        returns (bool)
    {
        uint256 borrowed = uint256(position[id][borrower].borrowShares).toAssetsUp(
            market[id].totalBorrowAssets, market[id].totalBorrowShares
        );
        uint256 maxBorrow = uint256(position[id][borrower].collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(marketParams.lltv);

        return maxBorrow >= borrowed;
    }

which causes the borrow function to revert with the INSUFFICIENT_COLLATERAL error at the following line:

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256) {
        ...

        require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL);
        ...
    }

We can infer that the \_isHealthy check is always returning false because the collateralPrice is set to its default 0 value since we never call the setPrice function to set it in our OracleMock.

So we can add a target function to allow the fuzzer to set the collateralPrice:

abstract contract TargetFunctions is
AdminTargets,
DoomsdayTargets,
ManagersTargets,
MorphoTargets
{
function oracle_setPrice(uint256 price) public {
oracle.setPrice(price);
}
}

Note that since we only needed a single handler we just added it to the TargetFunctions contract directly but if you're adding more than one handler it's generally a good practice to create a separate contract to inherit into TargetFunctions to keep things cleaner.

Now we can add our oracle_setPrice function to our sanity test to confirm that it works correctly and resolves the previous revert due to insufficient collateral:

    function test_crytic() public {
        morpho_supply_clamped(1e18);
        morpho_supplyCollateral_clamped(1e18);

        oracle_setPrice(1e30);

        morpho_borrow(1e6, 0, _getActor(), _getActor());
    }

which successfully passes:

[PASS] test_crytic() (gas: 249766)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 1.54ms (142.25µs CPU time)

With this test passing we can confirm that we have coverage over the primary functions in the Morpho contract that will allow us to explore the contract's state. Writing the type of sanity test like we did in the test_crytic function allows us to quickly debug simple issues that will prevent the fuzzer from reaching coverage before running it so that we're not stuck in a constant cycle of running and debugging only using the coverage report.

Now with this simple clamping in place we can let the fuzzer run for anywhere from 15 minutes to 2 hours to start building up a corpus and determine if there are any functions where coverage is being blocked.
Conclusion and Next Steps

We've seen above how we can set up and ensure coverage in invariant testing. Coverage is key because without it we can run the fuzzer indefintely but won't necessarily be testing meaningful states so it's always the most vital step that needs to be completed before implementing and testing properties.

In part 2, we'll look at how we can get to full meaningful coverage and some techniques we can implement to ensure better logical coverage so that we have a higher likelihood of reaching all lines of interest more frequently.

If you have any questions feel free to reach out to us in the Recon Discord channel

Recon Logo

    Introduction
    Writing Invariant Tests
    1. Learn Invariant Testing
    2. Example Project
    3. Implementing Properties
    4. Optimizing Broken Properties
    5. Advanced Fuzzing Tips
    6. Chimera Framework
    7. Create Chimera App
    Bootcamp
    8. Intro to the Bootcamp
    9. Part 1 - Invariant Testing with Chimera Framework
    10. Part 2 - Multidimensional Invariant Tests
    11. Part 3 - Writing and Breaking Properties
    12. Part 4 - Liquity Governance Case Study
    Using Recon
    13. Getting Started
    14. Upgrading to Pro
    15. Building Handlers
    16. Running Jobs
    17. Recon Magic
    18. Recipes
    19. Alerts
    20. Campaigns
    21. Dynamic Replacement
    22. Governance Fuzzing
    23. Recon Tricks
    Free Recon Tools
    24. Recon Extension
    25. Medusa Log Scraper
    26. Echidna Log Scraper
    27. Handler Builder
    28. Bytecode Compare
    29. Bytecode To Interface
    30. Bytecode Static Deployment
    31. Bytecode Formatter
    32. String To Bytes
    33. OpenZeppelin Roles Scraper
    OSS Repos
    34. Chimera
    35. Create Chimera App
    36. Log Parser
    37. ABI to Invariants
    38. ABI to Mock
    39. Setup Helpers
    40. Properties Table
    41. ERC7540 Reusable Properties
    OpSec
    42. OpSec Resources
    Help
    43. Glossary

Recon Book
Part 2 - Multidimensional Invariant Tests
Introduction and Goals

In part 1 we looked at how to setup Morpho with a Chimera invariant testing suite and get reasonable coverage over the lines of interest, in part 2 we'll look at how to achieve full line coverage over the remaining uncovered lines from the end of part 1.

    You can follow along using the repo with the scaffolding created in part 1 here.

Our goals for this section are: to reach 100% line coverage on the Morpho repo and explore ways to make our test suite capable of testing more possible setup configurations.

    For the recorded stream of this part of the bootcamp see here.

How to Evaluate Coverage Reports

From part 1 our MorphoTargets contract should have two clamped handlers (morpho_supply_clamped and morpho_supplyCollateral_clamped) and the remaining functions should be unclamped.

Having run Medusa with these functions implemented we should now see an increase in the coverage shown in our report:
Initial Coverage Improved Coverage

We can see from the above that after adding our improved setup and clamped handlers our coverage on Morpho increased from 28% to 77%. Medusa will now have these coverage increasing calls saved to the corpus for reuse in future runs, increasing its efficiency by not causing it to explore paths that always revert.

As we mentioned in part 1, the coverage report simply shows us which lines were successfully reached by highlighting them in green and shows which lines weren't reached by highlighting them in red.

Our approach for fixing coverage using the report will therefore consist of tracing lines that are green until we find a red line. The red line will then be an indicator of where the fuzzer was reverting. Once we find where a line is reverting we can then follow the steps outlined in part 1 where we create a unit test in the CryticToFoundry contract to determine why a line may always be reverting and introduce clamping or changes to the setup to allow us to reach the given line.
Coverage Analysis - Initial Results

It's important to note that although we mentioned above that our goal is to reach 100% coverage, this doesn't mean we'll try to blindly reach 100% coverage over all of a contract's lines because there are almost always certain functions whose behavior won't be of interest in an invariant testing scenario, like the extSloads function from the latest run:

ExtSload Missing Covg

Since this is a view function which doesn't change state we can safely say that covering it is unnecessary for our case.

    You should always use your knowledge of the system to make a judgement call about which functions in the system you can safely ignore coverage on. The functions that you choose to include should be those that test meaningful interactions including public/external functions, as well as the internal functions they call in their control flow.

In our case for Morpho we can say that for us to have 100% coverage we need to have covered the meaningful interactions a user could have with the contract which include borrowing, liquidating, etc..

When we look at coverage over the liquidate function, we can see that it appears to be reverting at the line that checks if the position is healthy:

Liquidate Missing Coverage

Meaning we need to investigate this with a Foundry unit test to understand what's causing it to always revert.

We can also see that the repay function similarly has only red lines after line 288, indicating that something may be causing it to always underflow:

Repay Underflow Coverage

However, note that the return value isn't highlighted at all, potentially indicating that there might also be an issue with the coverage displaying mechanism, so our approach to debugging this will be different, using a canary property instead.
Debugging With Canaries

We'll start with debugging the repay function using a canary because it's relatively simple. To do so we can create a simple boolean variable hasRepaid which we add to our Setup contract and set in our morpho_repay handler function:

abstract contract MorphoTargets is
BaseTargetFunctions,
Properties
{
function morpho_repay(uint256 assets, uint256 shares, address onBehalf, bytes memory data) public asActor {
morpho.repay(marketParams, assets, shares, onBehalf, data);
hasRepaid = true;
}
}

which will only set hasRepaid to true if the call to Morpho::repay completes successfully.

Then we can define a simple canary property in our Properties contract:

abstract contract Properties is BeforeAfter, Asserts {

    function canary_hasRepaid() public returns (bool) {
        t(!hasRepaid, "hasRepaid");
    }

}

this uses the t (true) assertion wrapper from the Asserts contract to let us know if the call to morpho.repay successfully completes by forcing an assertion failure if hasRepaid == true (remember that only assertion failures are picked up by Echidna and Medusa).

    See this section to better understand why we prefer to express properties using assertions rather than as boolean properties.

This function will randomly be called by the the fuzzer in the same way that the handler functions in TargetFunctions are called, allowing it to check if repay is called successfully after any of the state changing target function calls.

    While you're implementing the canary above you can run the fuzzer in the background to confirm that we're not simply missing coverage because of a lack of sufficient tests. It's always beneficial to have the fuzzer running in the background because it will build up a corpus that will make subsequent runs more efficient.

As a general naming convention for functions in our suites we use an underscore as a prefix to define what the function does, such as canary*, invariant*, property* or target contracts (morpho* in our case) then use camel case for the function name itself.

We can now run Medusa in the background to determine if we're actually reaching coverage over the repay function using the canary we've implemented while implementing our Foundry test to investigate the coverage issue with the liquidate function.
Investigating Liquidation Handler with Foundry

Now we'll use Foundry to investigate why the liquidate function isn't being fully covered. We can do this by expanding upon the test_crytic function we used in part 1 for our sanity tests.

To test if we can liquidate a user we'll just expand the existing test by setting the price to a very low value that should make the user liquidatable:

    function test_crytic() public {
        morpho_supply_clamped(1e18);
        morpho_supplyCollateral_clamped(1e18);

        oracle_setPrice(1e30);

        morpho_borrow(1e6, 0, _getActor(), _getActor());

        oracle_setPrice(0);

        // Note: we liquidate ourselves and pass in the amount of assets borrowed as the seizedAssets and 0 for the repaidShares for simplicity
        morpho_liquidate(_getActor(), 1e6, 0, "");
    }

After running the test we get the following output:

    ├─ [22995] Morpho::liquidate(MarketParams({ loanToken: 0xc7183455a4C133Ae270771860664b6B7ec320bB1, collateralToken: 0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9, oracle: 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a, irm: 0x2e234DAe75C793f67A35089C9d99245E1C58470b, lltv: 800000000000000000 [8e17] }), CryticToFoundry: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], 1000000 [1e6], 0, 0x)
    │   ├─ [330] Morpho::_accrueInterest(<unknown>, <unknown>)
    │   │   └─ ←
    │   ├─ [266] OracleMock::price() [staticcall]
    │   │   └─ ← [Return] 0
    │   ├─ [2585] Morpho::_isHealthy(<unknown>, <unknown>, 0x1B4D54357a97De46Aae0FBDfD649dD8190EF99Eb, 128)
    │   │   ├─ [356] SharesMathLib::toAssetsUp(1000000000000 [1e12], 1000000 [1e6], 1000000000000 [1e12])
    │   │   │   └─ ← 1000000 [1e6]
    │   │   ├─ [0] console::log("isHealthy", false) [staticcall]
    │   │   │   └─ ← [Stop]
    │   │   ├─ [0] console::log("collateralPrice", 0) [staticcall]
    │   │   │   └─ ← [Stop]
    │   │   └─ ← false
    │   ├─ [353] SharesMathLib::toSharesUp(1000000000000 [1e12], 1000000 [1e6], 0)
    │   │   └─ ← 0
    │   ├─ [356] SharesMathLib::toAssetsUp(1000000000000 [1e12], 1000000 [1e6], 0)
    │   │   └─ ← 0
    │   ├─ [198] UtilsLib::toUint128(0)
    │   │   └─ ← 0
    │   ├─ [198] UtilsLib::toUint128(0)
    │   │   └─ ← 0
    │   ├─ [198] UtilsLib::toUint128(1000000 [1e6])
    │   │   └─ ← 1000000 [1e6]
    │   ├─ [199] UtilsLib::toUint128(1000000 [1e6])
    │   │   └─ ← 1000000 [1e6]
    │   ├─ emit Liquidate(id: 0x5914fb876807b8cd7b8bc0c11b4d54357a97de46aae0fbdfd649dd8190ef99eb, caller: CryticToFoundry: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], borrower: CryticToFoundry: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], repaidAssets: 0, repaidShares: 0, seizedAssets: 1000000 [1e6], badDebtAssets: 0, badDebtShares: 0)

which indicates that we were able to successfully liquidate the user. This means that the fuzzer is theoretically able to achieve coverage over the entire liquidate function, it just hasn't yet because it hasn't found the right call sequence that allows it to pass the health check which verifies if a position is liquidatable which we saw from the coverage report above.
Tool Sophistication Limitations

After having run Medusa with the canary property created for the morpho_repay function we can see that it also doesn't break the property, confirming that the repay function is never fully covered:

⇾ [PASSED] Assertion Test: CryticTester.add_new_asset(uint8)
⇾ [PASSED] Assertion Test: CryticTester.asset_approve(address,uint128)
⇾ [PASSED] Assertion Test: CryticTester.asset_mint(address,uint128)
⇾ [PASSED] Assertion Test: CryticTester.canary_hasRepaid() /// @audit this should have failed
⇾ [PASSED] Assertion Test: CryticTester.morpho_accrueInterest()
⇾ [PASSED] Assertion Test: CryticTester.morpho_borrow(uint256,uint256,address,address)
⇾ [PASSED] Assertion Test: CryticTester.morpho_createMarket()
⇾ [PASSED] Assertion Test: CryticTester.morpho_enableIrm(address)
⇾ [PASSED] Assertion Test: CryticTester.morpho_enableLltv(uint256)
⇾ [PASSED] Assertion Test: CryticTester.morpho_flashLoan(address,uint256,bytes)
⇾ [PASSED] Assertion Test: CryticTester.morpho_liquidate(address,uint256,uint256,bytes)
⇾ [PASSED] Assertion Test: CryticTester.morpho_repay(uint256,uint256,address,bytes)
⇾ [PASSED] Assertion Test: CryticTester.morpho_setAuthorization(address,bool)
⇾ [PASSED] Assertion Test: CryticTester.morpho_setAuthorizationWithSig((address,address,bool,uint256,uint256),(uint8,bytes32,bytes32))
⇾ [PASSED] Assertion Test: CryticTester.morpho_setFee(uint256)
⇾ [PASSED] Assertion Test: CryticTester.morpho_setFeeRecipient(address)
⇾ [PASSED] Assertion Test: CryticTester.morpho_setOwner(address)
⇾ [PASSED] Assertion Test: CryticTester.morpho_supply(uint256,uint256,address,bytes)
⇾ [PASSED] Assertion Test: CryticTester.morpho_supply_clamped(uint256)
⇾ [PASSED] Assertion Test: CryticTester.morpho_supplyCollateral(uint256,address,bytes)
⇾ [PASSED] Assertion Test: CryticTester.morpho_supplyCollateral_clamped(uint256)
⇾ [PASSED] Assertion Test: CryticTester.morpho_withdraw(uint256,uint256,address,address)
⇾ [PASSED] Assertion Test: CryticTester.morpho_withdrawCollateral(uint256,address,address)
⇾ [PASSED] Assertion Test: CryticTester.oracle_setPrice(uint256)
⇾ [PASSED] Assertion Test: CryticTester.switch_asset(uint256)
⇾ [PASSED] Assertion Test: CryticTester.switchActor(uint256)
⇾ Test summary: 26 test(s) passed, 0 test(s) failed
⇾ html report(s) saved to: medusa/coverage/coverage_report.html
⇾ lcov report(s) saved to: medusa/coverage/lcov.info

The coverage report indicated this to us but sometimes the coverage report may show red lines followed by sequential green lines indicating there is an issue with the coverage report display so in those cases it's best to implement a canary property to determine if the fuzzer ever actually reaches the end of the function call.

We can then similarly test this with our sanity test to see if the fuzzer can ever theoretically reach this state:

    function test_crytic() public {
        morpho_supply_clamped(1e18);
        morpho_supplyCollateral_clamped(1e18);

        oracle_setPrice(1e30);

        morpho_borrow(1e6, 0, _getActor(), _getActor());

        morpho_repay(1e6, 0, _getActor(), "");
    }

When we run the above test we see that this also passes:

[PASS] test_crytic() (gas: 261997)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 7.43ms (1.18ms CPU time)

Ran 1 test suite in 149.79ms (7.43ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)

which again indicates that the fuzzer just hasn't run sufficiently long to find the right call sequence to allow the function to be fully covered.

The issue we're experiencing with missing coverage for short duration runs is because the fuzzer is fairly unsophisticated in its approach to finding the needed paths to reach the lines we're interested in so it often requires a significant amount of run time to achieve what to a human may be trivial to solve.

At this point we have two options since we know that these two functions can theoretically be covered with our current setup: we can either let the fuzzer run for an extended period of time and hope that it's long enough to reach these lines, or we can create clamped handlers which increase the likelihood that the fuzzer will cover these functions, we'll do the latter.
Creating Clamped Handlers

As noted above, for Medusa to reach full coverage on these functions it will just take an extended period of time (perhaps 12-24 or more hours of continuously running). But often if you're just trying to get full coverage and don't want to have to worry about needing a large corpus to ensure you're always effectively testing, introducing clamped handlers can be a simple way to speed up the time to reach full coverage while ensuring the test suite still explores all possible states.

So using the approach from part 1 we can create simple clamped handlers for the liquidate and repay functions:

abstract contract MorphoTargets is
BaseTargetFunctions,
Properties
{
function morpho_liquidate_clamped(uint256 seizedAssets, bytes memory data) public {
morpho_liquidate(\_getActor(), seizedAssets, 0, data);
}

    function morpho_repay_clamped(uint256 assets) public {
        morpho_repay(assets, 0, _getActor(), hex"");
    }

}

this again ensures that the clamped handler always calls the unclamped handler, simplifying things when we add tracking variables to our unclamped handler and also still allowing the unclamped handler to explore states not reachable by the clamped handler.

The utility \_getActor() function lets us pass its return value directly to our clamped handler to restrict it to be called for actors in the set managed by ActorManager. Calls for addresses other than these are not interesting to us because they wouldn't have been able to successfully deposit into the system since only the actors in the ActorManager are minted tokens in our setup.

    Clamping using the _getActor() function above in the call to morpho_liquidate would only result in self liquidations because the asActor modifier on the morpho_liquidate function would be called by the same actor. To allow liquidations by a different actor than the one being liquidated you could simply pass an entropy value to the clamped handler and use it to grab an actor from the actor array like: otherActor = _getActors()[entropy % _getActors().length].

Echidna Results

We can now add an additional canary to the morpho_liquidate function and run the fuzzer (Echidna this time to make sure it's not dependent on the existing Medusa corpus and to get accustomed to a different log output format). Pretty quickly our canaries break due to the clamping we added above, but our output is in the form of an unshrunken call sequence:

[2025-07-31 14:58:51.13] [Worker 6] Test canary*hasRepaid() falsified!
Call sequence:
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_withdrawCollateral(139165349852439003938912609244,0xffffffff,0x20000) from: 0x0000000000000000000000000000000000010000 Time delay: 166184 seconds Block delay: 31232
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.switch_asset(52340330059596290653834913136081606912886606264842484079177445013009074303725) from: 0x0000000000000000000000000000000000020000 Time delay: 4177 seconds Block delay: 11942
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setAuthorizationWithSig((0x1fffffffe, 0x2fffffffd, true, 2775883296381999636091875822520187953009296316518444142656228595165590339200, 84482743146605699262959509108986712558496212374847359617652247712552817589506),(151, "`k\151:qC\129FT\EOT\186\172\193\140\216\DC2\167\138\ESCJk\247\237\ESC\242u\NAK\142\141\FS\188\156", "P]\SOW\n\243zE_Z\EOT\254q8\161\165X9vs\157;}Q\231\156\134{\166\EM\166\185")) from: 0x0000000000000000000000000000000000010000 Time delay: 338920 seconds Block delay: 5237
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_createMarket_clamped(84,115792089237316195423570985008687907853269984665640564039457584007913129639931) from: 0x0000000000000000000000000000000000030000 Time delay: 379552 seconds Block delay: 9920
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.oracle_setPrice(40643094521925341163734482709707831340694913045806747257803475845392378675425) from: 0x0000000000000000000000000000000000030000 Time delay: 169776 seconds Block delay: 23978
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_accrueInterest() from: 0x0000000000000000000000000000000000010000 Time delay: 400981 seconds Block delay: 36859
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_borrow(4717137,1524785992,0x1fffffffe,0xd6bbde9174b1cdaa358d2cf4d57d1a9f7178fbff) from: 0x0000000000000000000000000000000000030000 Time delay: 112444 seconds Block delay: 59981
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_withdraw(1524785993,4370000,0x1fffffffe,0xd6bbde9174b1cdaa358d2cf4d57d1a9f7178fbff) from: 0x0000000000000000000000000000000000030000 Time delay: 24867 seconds Block delay: 36065
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_createMarket((0x20000, 0x1fffffffe, 0x0, 0x5615deb798bb3e4dfa0139dfa1b3d433cc23b72f, 2433501840534670638401877306933677925857482666649888441902487977779561405338)) from: 0x0000000000000000000000000000000000030000 Time delay: 569114 seconds Block delay: 22909
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_enableIrm(0x2e234dae75c793f67a35089c9d99245e1c58470b) from: 0x0000000000000000000000000000000000010000 Time delay: 419861 seconds Block delay: 53451
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supply_clamped(1356) from: 0x0000000000000000000000000000000000010000 Time delay: 31594 seconds Block delay: 2761
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_createMarket_clamped(255,20056265597397357382471408076278377684564781686653282536887372269507121043006) from: 0x0000000000000000000000000000000000010000 Time delay: 322247 seconds Block delay: 2497
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.switch_asset(4369999) from: 0x0000000000000000000000000000000000030000 Time delay: 127 seconds Block delay: 23275
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setFeeRecipient(0x20000) from: 0x0000000000000000000000000000000000030000 Time delay: 447588 seconds Block delay: 2497
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.switchActor(72588008080124735701161091986774009961001474157663624256168037189703653544743) from: 0x0000000000000000000000000000000000020000 Time delay: 15393 seconds Block delay: 48339
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_borrow(16613105090390601515239090669577198268868248614865818172825450329577079163584,21154678515745375889100650646505101526701555390905808907145126232472844598646,0x1fffffffe,0x1fffffffe) from: 0x0000000000000000000000000000000000020000 Time delay: 33605 seconds Block delay: 30042
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_enableIrm(0x3a6a84cd762d9707a21605b548aaab891562aab) from: 0x0000000000000000000000000000000000020000 Time delay: 82671 seconds Block delay: 60248
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_withdraw(62941804010087489725830203321595685812222552316557965638239257365793972413216,1524785991,0x1d1499e622d69689cdf9004d05ec547d650ff211,0xa0cb889707d426a7a386870a03bc70d1b0697598) from: 0x0000000000000000000000000000000000030000 Time delay: 276448 seconds Block delay: 2512
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_borrow(4370000,2768573972053683659826,0xffffffff,0x2e234dae75c793f67a35089c9d99245e1c58470b) from: 0x0000000000000000000000000000000000020000 Time delay: 19029 seconds Block delay: 12338
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_liquidate(0x2fffffffd,11460800875078169477147194839287647492117265203788714788708925236145309358714,10280738335691948395410926034882702684090815157987843691118830727301370669381,"\197c\216\197\&8\222\157\206\181u\205.\147\NUL\192&\191\252S\216fs\255\192bs~") from: 0x0000000000000000000000000000000000030000 Time delay: 490446 seconds Block delay: 35200
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_enableIrm(0x1fffffffe) from: 0x0000000000000000000000000000000000020000 Time delay: 519847 seconds Block delay: 47075
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supplyCollateral_clamped(87429830717447434093546417163411461590066543115446751961992901672555285315214) from: 0x0000000000000000000000000000000000030000 Time delay: 127 seconds Block delay: 2497
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_enableIrm(0xffffffff) from: 0x0000000000000000000000000000000000020000 Time delay: 112444 seconds Block delay: 53011
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_withdraw(4370000,78334692598020393677652884085155006796119597581000791874351453802511462037487,0x1fffffffe,0xd16d567549a2a2a2005aeacf7fb193851603dd70) from: 0x0000000000000000000000000000000000020000 Time delay: 419834 seconds Block delay: 12493
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_enableIrm(0xa4ad4f68d0b91cfd19687c881e50f3a00242828c) from: 0x0000000000000000000000000000000000010000 Time delay: 519847 seconds Block delay: 5237
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_createMarket((0x2fffffffd, 0x2fffffffd, 0x2fffffffd, 0xffffffff, 4370000)) from: 0x0000000000000000000000000000000000030000 Time delay: 73040 seconds Block delay: 27404
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_liquidate_clamped(1524785991,"\179t\219") from: 0x0000000000000000000000000000000000010000 Time delay: 24867 seconds Block delay: 59981
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setAuthorizationWithSig((0xc7183455a4c133ae270771860664b6b7ec320bb1, 0x3d7ebc40af7092e3f1c81f2e996cba5cae2090d7, false, 115792089237316195423570985008687907853269984665640564039457584007913129639931, 19328226267572242688271507287095356322934312678548014606211592404247528008431),(5, "\168\SI}\v\232*\164N\130hM\246\249\171#\SO\207C\182\201\145rI\213\173\"\169X&\213B\148", "\170\STXV2\236\159\nBZ\248\a\208\145\156\225\213&\184c0\NUL\164\239\215\131\215\176\236\222\206\241\167")) from: 0x0000000000000000000000000000000000010000 Time delay: 16802 seconds Block delay: 12338
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho*setAuthorizationWithSig((0xffffffff, 0xffffffff, false, 1524785991, 4370001),(132, "\196l\165gv\f#>\216GU\226<;o\190\172\164\159O\160\RS\RSq\230Q\233\&7~\DC4\129.", "(F,I\141\"\161\151V\*\ETB\220\US\188\147D\145\SYN\197\DC1\228\222E<\255\190\183\199\166\196!\182")) from: 0x0000000000000000000000000000000000030000 Time delay: 492067 seconds Block delay: 58783
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.switchActor(19649199686366011062803512568976588619112314940412432458583120627149961520044) from: 0x0000000000000000000000000000000000010000 Time delay: 31594 seconds Block delay: 24311
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setOwner(0x2fffffffd) from: 0x0000000000000000000000000000000000020000 Time delay: 156190 seconds Block delay: 30042
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supplyCollateral_clamped(4370000) from: 0x0000000000000000000000000000000000030000 Time delay: 434894 seconds Block delay: 38350
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setFeeRecipient(0x2fffffffd) from: 0x0000000000000000000000000000000000030000 Time delay: 487078 seconds Block delay: 45852
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_borrow(1524785993,0,0x7fa9385be102ac3eac297483dd6233d62b3e1496,0x2fffffffd) from: 0x0000000000000000000000000000000000030000 Time delay: 45142 seconds Block delay: 30042
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setAuthorization(0xffffffff,false) from: 0x0000000000000000000000000000000000020000 Time delay: 127251 seconds Block delay: 30784
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setOwner(0x2fffffffd) from: 0x0000000000000000000000000000000000030000 Time delay: 419861 seconds Block delay: 6116
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setAuthorizationWithSig((0xffffffff, 0xffffffff, true, 98023560194378278901182335731286893845369649171257963920947453536020479832694, 42531487871708039434445226744859689838438112427986407282965960331800976935919),(255, "\139\152E\251\a\132\163\176\161\GS\FSU*\SUB\141f\131\136\131\252$ $\CAN\213&y\187G]q\142", "\129\141!\r<\255e\166\ENQ\174\194\184\171K\txo\160\245\183\165\150\245\164u\186!\231\248d@g")) from: 0x0000000000000000000000000000000000010000 Time delay: 275394 seconds Block delay: 54155
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supply(78340293067286351700421412032466036153505569321862356155104413012425925305892,64900388158780783892669244892148232949424203977197049790349739320541455404460,0xc7183455a4c133ae270771860664b6b7ec320bb1,"\203\158s95") from: 0x0000000000000000000000000000000000030000 Time delay: 588255 seconds Block delay: 30304
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.asset_mint(0x2fffffffd,164863398856115715657560275188347377652) from: 0x0000000000000000000000000000000000020000 Time delay: 49735 seconds Block delay: 255
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_withdrawCollateral(1524785992,0xd16d567549a2a2a2005aeacf7fb193851603dd70,0x1fffffffe) from: 0x0000000000000000000000000000000000030000 Time delay: 289607 seconds Block delay: 22699
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setFee(30060947926930881215955423309556356762383357789761387983137622815863096422900) from: 0x0000000000000000000000000000000000010000 Time delay: 322374 seconds Block delay: 35200
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.asset_mint(0x1fffffffe,201575724203951298497109500251262201924) from: 0x0000000000000000000000000000000000010000 Time delay: 172101 seconds Block delay: 24987
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setFeeRecipient(0x5615deb798bb3e4dfa0139dfa1b3d433cc23b72f) from: 0x0000000000000000000000000000000000020000 Time delay: 434894 seconds Block delay: 38350
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supplyCollateral(95655969517338079568542754796826555155765084030581389603695924810962017720490,0x2fffffffd,"\221e") from: 0x0000000000000000000000000000000000010000 Time delay: 32767 seconds Block delay: 43261
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_withdraw(1524785992,1524785993,0x2fffffffd,0x10000) from: 0x0000000000000000000000000000000000010000 Time delay: 135921 seconds Block delay: 19933
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_enableLltv(63072166978742494423739555210865834901378841244451337092582777021427807180364) from: 0x0000000000000000000000000000000000020000 Time delay: 379552 seconds Block delay: 35393
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supply_clamped(1524785993) from: 0x0000000000000000000000000000000000030000 Time delay: 191165 seconds Block delay: 3661
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setFeeRecipient(0x2fffffffd) from: 0x0000000000000000000000000000000000010000 Time delay: 198598 seconds Block delay: 35727
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.add_new_asset(255) from: 0x0000000000000000000000000000000000010000 Time delay: 521319 seconds Block delay: 561
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_createMarket_clamped(114,14732638537083624345289335954617015250112438091124267754753001504400952630840) from: 0x0000000000000000000000000000000000030000 Time delay: 127251 seconds Block delay: 4223
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setAuthorizationWithSig((0x3a6a84cd762d9707a21605b548aaab891562aab, 0x2fffffffd, false, 0, 494),(107, "s\STXO\170Wa\165\178}\222\174\244\253\SUB,;\DLE\239\254_\\\203\233\136\176\t\150\236\152\223R\DC3", "i\217Q\199\247]V\217\218\STXnH\188\175\DC2S\212n6\138\208\SOH(\170\136NA\132\ACK\135YX")) from: 0x0000000000000000000000000000000000030000 Time delay: 379552 seconds Block delay: 260
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_borrow(1524785993,0,0x7fa9385be102ac3eac297483dd6233d62b3e1496,0x2fffffffd) from: 0x0000000000000000000000000000000000010000 Time delay: 100835 seconds Block delay: 42101
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setAuthorization(0x30000,false) from: 0x0000000000000000000000000000000000020000 Time delay: 136392 seconds Block delay: 2526
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_liquidate(0x1fffffffe,42,115792089237316195423570985008687907853269984665640564039457584007913129639935,"\SI \205\221\&8\\\233\131B\\\170\154\139\194\SUB\176\242\219V\NUL\246\189:*") from: 0x0000000000000000000000000000000000010000 Time delay: 401699 seconds Block delay: 5140
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setAuthorizationWithSig((0x2fffffffd, 0x2fffffffd, true, 98718112542795174780222117041749633036515850812239078969752153088362960804452, 59082813273560708554252437649099167166514405373127152335401515528348149263322),(14, "^#\246)^\130\DC1\167\t\231\221\142\SO\a#;\EOTh)\188\209\US5\244go\243]\198w\136\&4", ")\229\171\174\252\207\168\ESC\b\148ZR\250S\190\209\&5q\238\198zz\205\230\132\182\CAN\248\131<t\209")) from: 0x0000000000000000000000000000000000020000 Time delay: 332369 seconds Block delay: 12338
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supplyCollateral_clamped(393) from: 0x0000000000000000000000000000000000020000 Time delay: 136392 seconds Block delay: 23275
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_withdraw(4370000,88168885110079523116729640532378128948455763074151442754201129142029243467873,0x3d7ebc40af7092e3f1c81f2e996cba5cae2090d7,0x2fffffffd) from: 0x0000000000000000000000000000000000030000 Time delay: 554465 seconds Block delay: 30784
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.canary_hasLiquidated() from: 0x0000000000000000000000000000000000030000 Time delay: 136394 seconds Block delay: 53349
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.switch_asset(6972644) from: 0x0000000000000000000000000000000000020000 Time delay: 440097 seconds Block delay: 11942
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.asset_mint(0x1fffffffe,288045975658121479244861835043592183055) from: 0x0000000000000000000000000000000000010000 Time delay: 4177 seconds Block delay: 12053
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.asset_mint(0xd6bbde9174b1cdaa358d2cf4d57d1a9f7178fbff,41711746708650170008808164710389318524) from: 0x0000000000000000000000000000000000030000 Time delay: 209930 seconds Block delay: 12155
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_createMarket((0xffffffff, 0x1fffffffe, 0x0, 0xa0cb889707d426a7a386870a03bc70d1b0697598, 4370000)) from: 0x0000000000000000000000000000000000010000 Time delay: 344203 seconds Block delay: 54809
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_liquidate(0x1fffffffe,40373840526740839050196801193704937073898266292205731546154565460803927995135,29217591463335546937800419633742115545267222565624375091055595586860275593735,"O\137\149\134vK\137\249e\212\&0v\248\NULh\162\154'") from: 0x0000000000000000000000000000000000010000 Time delay: 111322 seconds Block delay: 59552
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supply(18004158537693769052070926907116349022576345496000691176340467249201776730440,4369999,0x1fffffffe,"\222L\213\f\235\138\189\193\r\215\152$l\225\165\&3\RSl\NUL7\198iQ\201\154\217O\DC2\170\243") from: 0x0000000000000000000000000000000000020000 Time delay: 275394 seconds Block delay: 19933
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.add_new_asset(241) from: 0x0000000000000000000000000000000000030000 Time delay: 82672 seconds Block delay: 11826
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_enableLltv(43156194238538479672366816039426317203377470164620094413833090790105307961583) from: 0x0000000000000000000000000000000000010000 Time delay: 289103 seconds Block delay: 34720
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supply_clamped(27974427792546532164293415827895807259179813205875291961017560107983336431691) from: 0x0000000000000000000000000000000000030000 Time delay: 487078 seconds Block delay: 32737
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setFeeRecipient(0x2fffffffd) from: 0x0000000000000000000000000000000000010000 Time delay: 116188 seconds Block delay: 59998
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setOwner(0xf62849f9a0b5bf2913b396098f7c7019b51a820a) from: 0x0000000000000000000000000000000000010000 Time delay: 305572 seconds Block delay: 42229
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setAuthorizationWithSig((0x7fa9385be102ac3eac297483dd6233d62b3e1496, 0x1fffffffe, false, 4370000, 113694143080975084215547446605886497531912965399599328542643253627763968653096),(103, "(\a\f\201\&1f\150\226\229\167\216f5d\t\236\161\DC21%C\NAK\195A\SYN\205\146\&5\151\253\197\t", "\v\145\149O\195\251\232\242\133\173\174\254\&5\155\136\224\245DGZ\ESC\166\192\183\235\RS\147&q\194n\235")) from: 0x0000000000000000000000000000000000030000 Time delay: 457169 seconds Block delay: 55538
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_repay_clamped(4369999) from: 0x0000000000000000000000000000000000030000 Time delay: 437838 seconds Block delay: 45819
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_liquidate(0x2fffffffd,52810212339586943686099208591755771434427525861105501860251480674091378931250,4370001,"\157Q\219\ENQu\160\133U\240,D\145\&8\148\164\215}\186\&0H\SOH\SOH\SOH\SOH\SOH\SOH\SOH\SOH\SOH\SOH\SOH\SOH\SOH\188\240\190\183") from: 0x0000000000000000000000000000000000010000 Time delay: 38059 seconds Block delay: 34272
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setOwner(0x30000) from: 0x0000000000000000000000000000000000010000 Time delay: 49735 seconds Block delay: 11826
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setFeeRecipient(0xffffffff) from: 0x0000000000000000000000000000000000010000 Time delay: 322374 seconds Block delay: 15368
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supplyCollateral(4370001,0x1fffffffe,"\218\196\228\148") from: 0x0000000000000000000000000000000000030000 Time delay: 127 seconds Block delay: 4896
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_createMarket((0x0, 0xffffffff, 0x1fffffffe, 0x2fffffffd, 115792089237316195423570985008687907853269984665640564039457584007913129639935)) from: 0x0000000000000000000000000000000000030000 Time delay: 444463 seconds Block delay: 30011
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supply(4370001,66832979790404067201096805386866048905938793568907012611547785706362720135665,0xf62849f9a0b5bf2913b396098f7c7019b51a820a,"\254\&6\139\220\201\241\DLE83\248I\207\146") from: 0x0000000000000000000000000000000000020000 Time delay: 275394 seconds Block delay: 5053
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.canary_hasRepaid() from: 0x0000000000000000000000000000000000030000 Time delay: 225906 seconds Block delay: 11349
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.asset_approve(0x10000,165609190392559895484641210287838517044) from: 0x0000000000000000000000000000000000030000 Time delay: 512439 seconds Block delay: 1362
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_repay_clamped(549254506228571780288208426538792742354690905907861302415970) from: 0x0000000000000000000000000000000000030000 Time delay: 112444 seconds Block delay: 12493
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setFee(113292422491629932223284832244308444917199192552263071449283252831384077866244) from: 0x0000000000000000000000000000000000020000 Time delay: 437838 seconds Block delay: 50499
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.oracle_setPrice(1859232730291432912269385173227438938201779297) from: 0x0000000000000000000000000000000000030000 Time delay: 82671 seconds Block delay: 23275
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_liquidate_clamped(10538888047983539263476186051641774148106703093301357864018304851672623648122,"r\218\241\RS") from: 0x0000000000000000000000000000000000010000 Time delay: 519847 seconds Block delay: 30304
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setOwner(0x10000) from: 0x0000000000000000000000000000000000030000 Time delay: 318197 seconds Block delay: 42595
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supplyCollateral(30251439192409875694466764232152102179766724355170846072199950999652926314734,0x1fffffffe,"\201I\133\ESC~\148\174\235\187\196\141\182\232\GS") from: 0x0000000000000000000000000000000000010000 Time delay: 24867 seconds Block delay: 22909
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.asset_mint(0xf62849f9a0b5bf2913b396098f7c7019b51a820a,1524785991) from: 0x0000000000000000000000000000000000030000 Time delay: 444463 seconds Block delay: 45852
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_createMarket_clamped(80,4787415) from: 0x0000000000000000000000000000000000030000 Time delay: 521319 seconds Block delay: 23978
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_repay_clamped(1524785993) from: 0x0000000000000000000000000000000000020000 Time delay: 82671 seconds Block delay: 49415
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_withdrawCollateral(17148736191729336842538147244438636401501412136166720330790724316212534695961,0xd6bbde9174b1cdaa358d2cf4d57d1a9f7178fbff,0xf62849f9a0b5bf2913b396098f7c7019b51a820a) from: 0x0000000000000000000000000000000000010000 Time delay: 437838 seconds Block delay: 800
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.asset_approve(0x2e234dae75c793f67a35089c9d99245e1c58470b,227828102580336275648345108956335259984) from: 0x0000000000000000000000000000000000010000 Time delay: 275394 seconds Block delay: 53678
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_repay(4370001,1524785993,0x2fffffffd,"ou(.s\207h\ETBE\141\221:\169SAl\155j\ESC\"R\US") from: 0x0000000000000000000000000000000000020000 Time delay: 289607 seconds Block delay: 2497
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supplyCollateral(4369999,0x212224d2f2d262cd093ee13240ca4873fccbba3c,"PL\174\131\216|\174") from: 0x0000000000000000000000000000000000020000 Time delay: 437838 seconds Block delay: 23885
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_withdraw(181,115792089237316195423570985008687907853269984665640564039457584007913129639934,0x1fffffffe,0xffffffff) from: 0x0000000000000000000000000000000000020000 Time delay: 407328 seconds Block delay: 12053
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.asset_approve(0x1d1499e622d69689cdf9004d05ec547d650ff211,1524785992) from: 0x0000000000000000000000000000000000010000 Time delay: 478623 seconds Block delay: 23885
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_borrow(1524785993,0,0x7fa9385be102ac3eac297483dd6233d62b3e1496,0x2fffffffd) from: 0x0000000000000000000000000000000000010000 Time delay: 332369 seconds Block delay: 15367
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_repay_clamped(4370000) from: 0x0000000000000000000000000000000000010000 Time delay: 136393 seconds Block delay: 55538
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.oracle_setPrice(314193065261808602749399333593851483) from: 0x0000000000000000000000000000000000010000 Time delay: 525476 seconds Block delay: 23978
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_createMarket_clamped(94,4370000) from: 0x0000000000000000000000000000000000030000 Time delay: 322374 seconds Block delay: 52262
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_setAuthorization(0x3a6a84cd762d9707a21605b548aaab891562aab,false) from: 0x0000000000000000000000000000000000030000 Time delay: 166184 seconds Block delay: 59982
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.canary_hasRepaid() from: 0x0000000000000000000000000000000000030000 Time delay: 588255 seconds Block delay: 4223

which is almost entirely unintelligible and impossible to use for debugging.

Thankfully when we have the breaking call sequences in hand we can stop the fuzzer (cancel button in the Recon extension or crtl + c using the CLI) which will allow Echidna to take the very large and indecipherable call sequences and reduce them to the minimum calls required to break the property using shrinking:

...
canary_hasLiquidated(): failed!💥
Call sequence:
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.oracle_setPrice(2000260614577296095635199229595241992)
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supplyCollateral_clamped(1)
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_borrow(0,1,0x7fa9385be102ac3eac297483dd6233d62b3e1496,0xdeadbeef)
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.oracle_setPrice(0)
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_liquidate_clamped(1,"")
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.canary_hasLiquidated()

Traces:
emit Log(«hasLiquidated»)

...

canary_hasRepaid(): failed!💥
Call sequence:
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supplyCollateral_clamped(1)
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_supply_clamped(1)
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.oracle_setPrice(2002586819475893397607592226441960698)
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_borrow(1,0,0x7fa9385be102ac3eac297483dd6233d62b3e1496,0xdeadbeef)
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.morpho_repay_clamped(1)
0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496.canary_hasRepaid()

Traces:
emit Log(«hasRepaid»)

...

And once again if we've run Echidna using the Recon extension it will automatically generate Foundry reproducer unit tests for the breaking call sequences which get added to the CryticToFoundry contract.

// forge test --match-test test_canary_hasLiquidated_0 -vvv
function test_canary_hasLiquidated_0() public {
oracle_setPrice(2000260614577296095635199229595241992);
morpho_supplyCollateral_clamped(1);
morpho_borrow(0,1,0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496,0x00000000000000000000000000000000DeaDBeef);
oracle_setPrice(0);
morpho_liquidate_clamped(1,hex"");
canary_hasLiquidated();
}

// forge test --match-test test_canary_hasRepaid_1 -vvv
function test_canary_hasRepaid_1() public {
morpho_supplyCollateral_clamped(1);
morpho_supply_clamped(1);
oracle_setPrice(2002586819475893397607592226441960698);
morpho_borrow(1,0,0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496,0x00000000000000000000000000000000DeaDBeef);
morpho_repay_clamped(1);
canary_hasRepaid();
}

Since these reproducers are for canary properties they just prove to us that using our clamped handlers the fuzzer has been able to find a call sequence that allows it to successfully call repay and liquidate.
Remaining Coverage Issues

Now that we've confirmed that we have coverage over the two functions of interest that weren't previously getting covered, we can check the coverage report to see what remains uncovered:

Additional Missing Coverage

from which we can determine that the line that's not being covered is because our clamped handler is always passing in a nonzero value for the seizedAssets parameter.

This shows that even though we're getting coverage in the sense that we successfully call the function, we aren't getting full branch coverage for all the possible paths that can be taken within the functions themselves because certain lines are difficult for the fuzzer to reach with its standard approach.

We're again faced with the option to either let the fuzzer run for an extended period of time or add additional clamped handlers. We'll take the approach of adding additional clamped handlers in this case because the issue blocking coverage is relatively straightforward but when working with a more complex project it may make sense to just run a long duration job using something like the Recon Cloud Runner.
Creating Additional Clamped Handlers

We'll now add a clamped handler for liquidating shares which allows for 0 seizedAssets:

abstract contract MorphoTargets is
BaseTargetFunctions,
Properties
{
...

    function morpho_liquidate_assets(uint256 seizedAssets, bytes memory data) public {
        morpho_liquidate(_getActor(), seizedAssets, 0, data);
    }

    function morpho_liquidate_shares(uint256 shares, bytes memory data) public {
        morpho_liquidate(_getActor(), 0, shares, data);
    }

}

Which should give us coverage over the missing line highlighted above.

We can then run Echidna again for 5-10 minutes and see that we now cover the previously uncovered line.

Liquidate Fixed Coverage
Dynamic Market Creation

With full coverage achieved over the functions of interest in our target contract we can now further analyze our existing setup and see where it could be improved.

Note that our statically deployed market which we previously added in the setup function in part 1 only allowed us to test one market configuration which may prevent the fuzzer from finding interesting cases related to different market configurations:

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
...

    /// === Setup === ///
    function setup() internal virtual override {
        ...

        address[] memory assets = _getAssets();
        marketParams = MarketParams({
            loanToken: assets[1],
            collateralToken: assets[0],
            oracle: address(oracle),
            irm: address(irm),
            lltv: 8e17
        });
        morpho.createMarket(marketParams);
    }

}

We can replace this with a dynamic function which instead takes fuzzed values and allows us to test the system with more possible configurations, adding a new dimensionality to our test suite. We'll add the following function to our TargetFunctions contract to allow us to do this:

    function morpho_createMarket_clamped(uint8 index, uint256 lltv) public {
        address loanToken = _getAssets()[index % _getAssets().length];
        address collateralToken = _getAsset();

        marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: address(oracle),
            irm: address(irm),
            lltv: lltv
        });

        morpho_createMarket(marketParams);
    }

which just requires that we modify the original morpho_createMarket target function to receive a \_marketParams argument:

    function morpho_createMarket(MarketParams memory _marketParams) public asActor {
        morpho.createMarket(_marketParams);
    }

This allows us to introduce even more possible market configurations than just those using the tokens we deployed in the Setup because the fuzzer will also be able to call the add_new_asset function via the ManagersTargets:

    function add_new_asset(uint8 decimals) public returns (address) {
        address newAsset = _newAsset(decimals);
        return newAsset;
    }

which deploys an additional asset with a random number of decimals. This can be particularly useful for testing low or high decimal precision tokens which can often reveal edge cases related to how they're handled in math operations.
Conclusion and Next Steps

We've looked at how we can scaffold a contract and get to 100% meaningful coverage using Chimera and use the randomness of the fuzzer to test additional configuration parameters not possible with only a static setup.

In part 3 we'll look at how we can further use Chimera for its main purpose of writing and breaking properties with different tools.

If you'd like to see more examples of how to scaffold projects with Chimera checkout the following podcasts:

    Fuzzing MicroStable with Echidna | Alex & Shafu on Invariant Testing
    Using Recon Pro to test invariants in the cloud | Alex & Austin Griffith

If you have any questions feel free to reach out to the Recon team in the help channel of our discord.

Recon Logo

    Introduction
    Writing Invariant Tests
    1. Learn Invariant Testing
    2. Example Project
    3. Implementing Properties
    4. Optimizing Broken Properties
    5. Advanced Fuzzing Tips
    6. Chimera Framework
    7. Create Chimera App
    Bootcamp
    8. Intro to the Bootcamp
    9. Part 1 - Invariant Testing with Chimera Framework
    10. Part 2 - Multidimensional Invariant Tests
    11. Part 3 - Writing and Breaking Properties
    12. Part 4 - Liquity Governance Case Study
    Using Recon
    13. Getting Started
    14. Upgrading to Pro
    15. Building Handlers
    16. Running Jobs
    17. Recon Magic
    18. Recipes
    19. Alerts
    20. Campaigns
    21. Dynamic Replacement
    22. Governance Fuzzing
    23. Recon Tricks
    Free Recon Tools
    24. Recon Extension
    25. Medusa Log Scraper
    26. Echidna Log Scraper
    27. Handler Builder
    28. Bytecode Compare
    29. Bytecode To Interface
    30. Bytecode Static Deployment
    31. Bytecode Formatter
    32. String To Bytes
    33. OpenZeppelin Roles Scraper
    OSS Repos
    34. Chimera
    35. Create Chimera App
    36. Log Parser
    37. ABI to Invariants
    38. ABI to Mock
    39. Setup Helpers
    40. Properties Table
    41. ERC7540 Reusable Properties
    OpSec
    42. OpSec Resources
    Help
    43. Glossary

Recon Book
Part 3 - Writing and Breaking Properties
Introduction and Goals

In this section we'll finally get to exploring the reason why invariant testing is valuable: breaking properties, but first we need to understand how to define and implement them.

    For the recorded stream of this part of the bootcamp see here.

Additional points on Chimera architecture

In parts 1 and 2 we primarily looked at targets defined in the MorphoTargets contract, but when you scaffold with Chimera you also get the AdminTargets, DoomsdayTargets and ManagersTargets contracts generated automatically.

We'll look at each of these more in depth below but before doing so here's a brief overview of each:

    AdminTargets - target functions that should only be called by a system admin (uses the asAdmin modifier to call as our admin actor)
    DoomsdayTargets - special tests with multiple state changing operations in which we add inlined assertions to test specific scenarios
    ManagersTargets - target functions that allow us to interact with any manager used in our system (ActorManager and AssetManager are added by default)

The three types of properties

When discussing properties it's easy to get caught-up in the subtleties of the different types, but for this overview we'll just stick with three general ideas for properties that will serve you well.

    If you want to learn more about the subtleties of different property types, see this section on implementing properties.

1. Global Properties

Global properties, as the name implies, make assertions on the global state of the system, which can be defined by reading values from state variables or by added tracking variables that define values not stored by state variables.

An example of a global property that can be defined in many system types is a solvency property. For a solvency property we effectively query the sum of balances of the token, then query the balance in the system and make an assertion:

    /// @dev simple solvency property that checks that a ERC4626 vault always has sufficient assets to exchange for shares
    function property_solvency() public {
        address[] memory actors = _getActors();

        // sums user shares of the vault token
        uint256 sumUserShares;
        for (uint256 i; i < actors.length; i++) {
            sumUserShares += vault.balanceOf(actors[i]);
        }
        // converts sum of user shares to vault's underlying assets
        uint256 sharesAsAssets = vault.convertToAssets(sumUserShares);

        // fetches underlying asset balance of vault
        uint256 vaultUnderlyingBalance = IERC20(vault.asset()).balanceOf(address(vault));

        // asserts that the vault must always have a sufficient amount of assets to repay the shares converted to assets
        gte(vaultUnderlyingBalance, sharesAsAssets, "vault is insolvent");
    }

In the above example, any time the system's balance is less than the sum of shares converted to the underlying asset, the system is insolvent because it would be unable to fulfill all repayments.

    Interesting states that can be checked with global properties usually either take the form of one-to-one variable checks like checking a user balance versus balance tracked in the system or aggregated checks like the sum of all user balances versus sum of all internal balances.

2. State Changing Properties

State changing properties allow us to verify how the state of a system evolves over time with calls to state changing functions.

For example, we could verify that for a deposit into a vault, a user's balance of the share token is increased by the correct amount:

    /// @dev inline property to check that user isn't minted more shares than expected
    function vault_deposit(uint256 assets, address receiver) public {
        // fetch the amount of expected shares to be received for depositing a given amount of assets
        uint256 expectedShares = vault.previewDeposit(assets);
        // fetch user shares before deposit
        uint256 sharesBefore = vault.balanceOf(receiver);

        // make the deposit
        vault.deposit(assets, receiver);

        // fetch user shares after deposit
        uint256 sharesAfter = vault.balanceOf(receiver);

        // assert that user doesn't gain more shares than expected
        lte(sharesAfter, sharesBefore + expectedShares, "user receives more than expected shares");
    }

The check in the above goes a step beyond a simple equality check and confirms that the user doesn't gain more shares than expected. This is helpful for finding issues where the vault may round in favor of the user instead of the protocol, potentially leading to insolvency.

Although these types of checks may seem basic, you'd be surprised how many times they've led to uncovering edge cases in private audits for the Recon team.
Dealing with complex tests

Global and state changing properties allow making an assertion after an individual state change is made, but sometimes you'll want to check how multiple specific state changes affect the system.

For these checks you can use the stateless modifier which reverts all state changes after the function call:

    modifier stateless() {
        _;
        revert("stateless");
    }

This allows you to perform the specific check without maintaining state changes in the next target function call.

Adding the stateless modifier to functions defined in DoomsdayTargets therefore lets us test specific cases which make multiple state changes or modify the input to the target function in some way. For example, we can check if withdrawing a user's entire maxWithdraw amount from a vault sets the user's maxWithdraw to 0 after:

    function doomsday_maxWithdraw() public stateless {
        uint256 maxWithdrawBefore = vault.maxWithdraw(_getActor());

        vault.withdraw(amountToWithdraw, _getActor(), _getActor());

        uint256 maxWithdrawAfter = vault.maxWithdraw(_getActor);
        eq(maxWithdrawAfter, 0, "maxWithdraw after withdrawing all is nonzero");
    }

If the assertion above fails, we'll get a reproducer unit test in which the doomsday_maxWithdraw function is the last one called. If the assertion doesn't fail, the fuzzer will revert the state changes meaning it won't be included in the shrunken reproducer for any other broken properties. As a result, the function that's used for exploring state changes related to withdrawals will be the primary withdrawal handler function: vault_withdraw.

Using this technique ensures that the actual state exploration done by the fuzzer is handled only by the target functions which call one state changing function at a time and have descriptive names. This approach keeps what we call the "story" clean, where the story is the call sequence that's used to break a property in a reproducer unit test. Having each individual handler responsible for one state changing call makes it easier to understand how the state evolves when looking at the test.
Practical exercise: RewardsManager

For our example we'll be looking at the RewardsManager contract, in this repo.

First we'll use the Recon extension to add a Chimera scaffolding to the project like we did in part 1, then focus on how we can get full coverage and finally implement the properties.

This is typically how we structure our engagements at Recon, as we outlined in this section of the intro as these steps need to preceed one another to be maximally effective and reduce the amount of time spent debugging issues.
Scaffolding

We can use the same process for scaffolding as we did in part 1. After scaffolding the RewardsManager, we should have the following target functions:

abstract contract RewardsManagerTargets is
BaseTargetFunctions,
Properties
{

    function rewardsManager_accrueUser(uint256 epochId, address vault, address user) public asActor {
        rewardsManager.accrueUser(epochId, vault, user);
    }

    function rewardsManager_accrueVault(uint256 epochId, address vault) public asActor {
        rewardsManager.accrueVault(epochId, vault);
    }

    function rewardsManager_addBulkRewards(uint256 epochStart, uint256 epochEnd, address vault, address token, uint256[] memory amounts) public asActor {
        rewardsManager.addBulkRewards(epochStart, epochEnd, vault, token, amounts);
    }

    function rewardsManager_addBulkRewardsLinearly(uint256 epochStart, uint256 epochEnd, address vault, address token, uint256 total) public asActor {
        rewardsManager.addBulkRewardsLinearly(epochStart, epochEnd, vault, token, total);
    }

    function rewardsManager_addReward(uint256 epochId, address vault, address token, uint256 amount) public asActor {
        rewardsManager.addReward(epochId, vault, token, amount);
    }

    function rewardsManager_claimBulkTokensOverMultipleEpochs(
        uint256 epochStart,
        uint256 epochEnd,
        address vault,
        address[] memory tokens,
        address user
    ) public asActor {
        rewardsManager.claimBulkTokensOverMultipleEpochs(epochStart, epochEnd, vault, tokens, user);
    }

    function rewardsManager_claimReward(uint256 epochId, address vault, address token, address user) public asActor {
        rewardsManager.claimReward(epochId, vault, token, user);
    }

    function rewardsManager_claimRewardEmitting(uint256 epochId, address vault, address token, address user) public asActor {
        rewardsManager.claimRewardEmitting(epochId, vault, token, user);
    }

    function rewardsManager_claimRewardReferenceEmitting(uint256 epochId, address vault, address token, address user) public asActor {
        rewardsManager.claimRewardReferenceEmitting(epochId, vault, token, user);
    }

    function rewardsManager_claimRewards(
        uint256[] memory epochsToClaim,
        address[] memory vaults,
        address[] memory tokens,
        address[] memory users
    ) public asActor {
        rewardsManager.claimRewards(epochsToClaim, vaults, tokens, users);
    }

    function rewardsManager_notifyTransfer(address from, address to, uint256 amount) public asActor {
        rewardsManager.notifyTransfer(from, to, amount);
    }

    function rewardsManager_reap(RewardsManager.OptimizedClaimParams memory params) public asActor {
        rewardsManager.reap(params);
    }

    function rewardsManager_tear(RewardsManager.OptimizedClaimParams memory params) public asActor {
        rewardsManager.tear(params);
    }

}

Since the RewardsManager has no constructor arguments, we can see that the project immediately compiles without needing to modify our setup function:

forge build
[⠊] Compiling...
[⠑] Compiling 56 files with Solc 0.8.24
[⠘] Solc 0.8.24 finished in 702.49ms
Compiler run successful!

letting us move onto the next step of expanding our setup to improve our line and logical coverage.
Setting up actors and assets

The first step for improving our test setup will be adding three additional actors and token deployments of varying decimal values to the setup function:

    function setup() internal virtual override {
        rewardsManager = new RewardsManager();

        // Add 3 additional actors (default actor is address(this))
        _addActor(address(0x411c3));
        _addActor(address(0xb0b));
        _addActor(address(0xc0ff3));

        // Deploy MockERC20 assets
        _newAsset(18);
        _newAsset(8);
        _newAsset(6);

        // Mints to all actors and approves allowances to the counter
        address[] memory approvalArray = new address[](1);
        approvalArray[0] = address(rewardsManager);
        _finalizeAssetDeployment(_getActors(), approvalArray, type(uint88).max);
    }

    Note that in the ActorManager, the default actor is address(this) which also serves as the "admin" actor which we use to call privileged functions via the asAdmin modifier.

The RewardsManager doesn't implement access control mechanisms, but we can simulate privileged functions only being called by the admin actor using the CodeLense provided by the Recon extension to replace the asActor modifier with the asAdmin modifier on our functions of interest:

Codelense Example

and subsequently relocating these functions to the AdminTargets contract. In a real-world setup this allows testing admin functions that would be called in regular operations by ensuring these target functions are always called with the correct actor so they don't needlessly revert.

We'll apply the above mentioned changes to the rewardsManager_addBulkRewards, rewardsManager_addBulkRewardsLinearly, rewardsManager_addReward and rewardsManager_notifyTransfer functions:

abstract contract AdminTargets is
BaseTargetFunctions,
Properties
{
function rewardsManager_addBulkRewards(uint256 epochStart, uint256 epochEnd, address vault, address token, uint256[] memory amounts) public asAdmin {
rewardsManager.addBulkRewards(epochStart, epochEnd, vault, token, amounts);
}

    function rewardsManager_addBulkRewardsLinearly(uint256 epochStart, uint256 epochEnd, address vault, address token, uint256 total) public asAdmin {
        rewardsManager.addBulkRewardsLinearly(epochStart, epochEnd, vault, token, total);
    }

    function rewardsManager_addReward(uint256 epochId, address vault, address token, uint256 amount) public asAdmin {
        rewardsManager.addReward(epochId, vault, token, amount);
    }

    function rewardsManager_notifyTransfer(address from, address to, uint256 amount) public asAdmin {
        rewardsManager.notifyTransfer(from, to, amount);
    }

}

This leaves our RewardsManagerTargets cleaner and makes it easier to distinguish user actions from admin actions.
Creating clamped handlers

Looking at our target functions we can see there are 3 primary values that we'll need to clamp if we don't want the fuzzer to spend an inordinate amount of time exploring states that are irrelevant: address vault, address token and address user:

abstract contract RewardsManagerTargets is
BaseTargetFunctions,
Properties
{
...

    function rewardsManager_accrueUser(uint256 epochId, address vault, address user) public asActor {
        rewardsManager.accrueUser(epochId, vault, user);
    }

    ...

    function rewardsManager_claimRewardEmitting(uint256 epochId, address vault, address token, address user) public asActor {
        rewardsManager.claimRewardEmitting(epochId, vault, token, user);
    }

    ...

}

Thankfully our setup handles tracking for two of the values we need, so we can clamp token with the value returned by \_getAsset() and the user with the value returned by \_getActor(). For simplicity we'll clamp the vault using address(this), this saves us from having to implement a mock vault which we'd have to add to our actors to call the handlers with.

We'll start off by only clamping the claimReward function because it should allow us to reach decent coverage after our first run of the fuzzer:

abstract contract RewardsManagerTargets is
BaseTargetFunctions,
Properties
{
function rewardsManager_claimReward_clamped(uint256 epochId) public asActor {
rewardsManager_claimReward(epochId, address(this), \_getAsset(), \_getActor());
}
}

We can then run Echidna in exploration mode (which only tries to increase coverage without testing properties) for 10-20 minutes to see how many of the lines of interest get covered with this minimal clamping applied:

Echidna Exploration Mode
Coverage analysis

After stopping the fuzzer, we can see from the coverage report that all the major functions of interest: notifyTransfer, \_handleDeposit, \_handleWithdrawal, \_handleTransfer, and accrueVault are fully covered:

Rewards Manager Initial Coverage

We can also see, however, that the claimReward function is only being partially covered:

Claim Reward Coverage

specifically, the epoch for which a user is claiming rewards never has any points accumulated for it, so it never has anything to claim.

We can use this additional information to improve our rewardsManager_claimReward_clamped function further:

    function rewardsManager_claimReward_clamped(uint256 epochId) public asActor {
        uint256 maxEpoch = rewardsManager.currentEpoch();
        epochId = epochId % (maxEpoch + 1);

        rewardsManager_claimReward(epochId, address(this), _getAsset(), _getActor());
    }

which ensures that we only claim rewards for an epochId that has already passed, which makes it more likely that there will be points accumulated for it.

We can then start a new run of the fuzzer and confirm that this has improved coverage as expected:

Improved Claim Reward Coverage

Now with a setup that works and coverage over the functions of interest we can move on to the property writing phase.
About the RewardsManager contract

Before implementing the properties themselves we need to get a high-level understanding of how the system works. This is essential for effective invariant testing when you're unfamiliar with the codebase because it helps you define meaningful properties.

    Typically if you designed/implemented the system yourself you'll already have a pretty good idea of what the properties you want to define are so you can skip this step and start defining properties right away.

The RewardsManager, as the name implies, is meant to handle the accumulation and distribution of reward tokens for depositors into a system. Since token rewards are often used as an incentive for providing liquidity to protocols, typically via vaults, this contract is meant to integrate with vaults via a notification system which is triggered by user deposits/withdrawals/transfers. This subsequently updates reward tracking for a user so any holder of the vault token can receive rewards proportional to the amount of time for which they're deposited.

The key function in the notification system that handles this is notifyTransfer:

    function notifyTransfer(address from, address to, uint256 amount) external {
        require(from != to, "Cannot transfer to yourself");

        if (from == address(0)) {
            _handleDeposit(msg.sender, to, amount);
        } else if (to == address(0)) {
            _handleWithdrawal(msg.sender, from, amount);
        } else {
            _handleTransfer(msg.sender, from, to, amount);
        }

        emit Transfer(msg.sender, from, to, amount);
    }

which decrements or increments the reward tracking for a given user based on the action taken.

Looking at the \_handleDeposit function more closely:

    function _handleDeposit(address vault, address to, uint256 amount) internal {
        uint256 cachedCurrentEpoch = currentEpoch();
        accrueUser(cachedCurrentEpoch, vault, to);
        // We have to accrue vault as totalSupply is gonna change
        accrueVault(cachedCurrentEpoch, vault);

        unchecked {
            // Add deposit data for user
            shares[cachedCurrentEpoch][vault][to] += amount;
        }
        // Add total shares for epoch // Remove unchecked per QSP-5
        totalSupply[cachedCurrentEpoch][vault] += amount;

    }

we can see that it accrues rewards to the user and the vault based on the time since the last accrual. It then increases the shares accounted to the user for the current epoch which determine a user's fraction of the total rewards as a fraction of the total shares for the epoch.
Initial property outline

Now that we have an understanding of how the system works, we can define our first properties.

From the above function we can define a solvency property as: "the totalSupply of tracked shares is the sum of user share balances":

totalSupply == SUM(shares[vault][users])

which ensures that we never have more shares accounted to users than the totalSupply we're tracking.

In addition to the solvency property, we can also define a property that states that: "the sum of accumulated rewards are less than or equal to the reward token balance of the RewardsManager":

SUM(rewardsInfo[epochId][vaultAddress][tokenAddress]) <= rewardToken.balanceOf(address(rewardsManager))

Implementing the first properties

Often it's good to write out properties as pseudo-code before implementing in Solidity because it allows us to understand which values we can read from state and which we'll need to add additional tracking for.

In our case we can use our property definitions:

    the totalSupply of shares tracked is the sum of user share balances
    the sum of rewards are less than or equal to the reward token balance of the RewardsManager

To outline the following pseudocode:

## Property 1

For each epoch, sum all user share balances (`sharesAtEpoch`) by looping through all actors (returned by `_getActors()`)

Assert that `totalSupply` for the given epoch is the same as the sum of shares `totalSupply == sharesAtEpoch`

## Property 2

For each epoch, sum all rewards for `address(this)` (our placeholder for the vault)

Using the sum of the above, assert that `total <= token.balanceOf(rewardsManager)`

Implementing the total supply solvency property

We can then use the pseudocode to guide the implementation of the first property in the Properties contract:

    function property_totalSupplySolvency() public {
        // fetch the current epoch up to which rewards have been accumulated
        uint256 currentEpoch = rewardsManager.currentEpoch();
        uint256 epoch;

        while(epoch < currentEpoch) {
            uint256 sharesAtEpoch;

            // sum over all users
            for (uint256 i = 0; i < _getActors().length; i++) {
                uint256 shares = rewardsManager.shares(epoch, address(this), _getActors()[i]);
                sharesAtEpoch += shares;
            }

            // check that sum of user shares for an epoch is the same as the totalSupply for that epoch
            eq(sharesAtEpoch, rewardsManager.totalSupply(epoch, address(this)), "Sum of user shares should equal total supply");

            epoch++;
        }

    }

In the above since the RewardsManager contract checkpoints the totalSupply for each epoch and also tracks user shares for each epoch, the only additional tracking we need to add is an accumulator for the sum of user shares which we use to make our assertion against the totalSupply.

We can then start a new run of the fuzzer with our implemented property to see if it breaks. Ideally you should always run the fuzzer for around 5 minutes after implementing a property (or a few) because it allows you to quickly determine whether your property is correct or whether it breaks as a false positive (most false positives can be triggered with a relatively short run because they're either due to missing preconditions or a misunderstanding of how the system actually works in the property implementation).

    Implementing many properties without running the fuzzer could result in many false positives that all need to be debugged separately and rerun to confirm they're resolved which ultimately slows down your implementation cycle.

Property refinement process

Very shortly after we start running the fuzzer it breaks the property, so we can stop the fuzzer and generate a reproducer using the Recon extension automatically (or use the Recon log scraper tool to generate one):

    function test_property_totalSupplySolvency_0() public {
        vm.warp(block.timestamp + 157880);
        vm.roll(block.number + 1);
        rewardsManager_notifyTransfer(0x0000000000000000000000000000000000000000,0x00000000000000000000000000000000DeaDBeef,1);

        vm.warp(block.timestamp + 446939);
        vm.roll(block.number + 1);
        property_totalSupplySolvency();
    }

We can see from this that the only state-changing call that was made in the sequence was to rewardsManager_notifyTransfer, which indicates that this is most likely a false positive, which we can confirm by checking the handler function implementation in AdminTargets:

abstract contract AdminTargets is
BaseTargetFunctions,
Properties
{
...

    function rewardsManager_notifyTransfer(address from, address to, uint256 amount) public asAdmin {
        rewardsManager.notifyTransfer(from, to, amount);
    }

}

From the handler it becomes clear that the notifyTransfer function results in a call to the internal \_handleDeposit function since the from address in the test is address(0):

    function notifyTransfer(address from, address to, uint256 amount) external {
        ...

        if (from == address(0)) {
            /// @audit this line gets hit
            _handleDeposit(msg.sender, to, amount);
        } else if (to == address(0)) {
            _handleWithdrawal(msg.sender, from, amount);
        } else {
            _handleTransfer(msg.sender, from, to, amount);
        }

        ...
    }

This results in deposited shares being accounted for the 0x00000000000000000000000000000000DeaDBeef address. Since we only sum over the share balance of all actors tracked in ActorManager in the property, it doesn't account for other addresses (such as 0x00000000000000000000000000000000DeaDBeef) having received shares, and so we get a 0 value for the sum in sharesAtEpoch and a value of 1 wei for the totalSupply at the current epoch.

To ensure we're only allowing transfers to actors tracked by our ActorManager we can clamp the to address to the currently set actor using \_getActor():

    function rewardsManager_notifyTransfer(address from, uint256 amount) public asAdmin {
        rewardsManager.notifyTransfer(from, _getActor(), amount);
    }

This type of clamping is often essential to prevent these types of false positives, so we don't implement them in a separate clamped handler (as this would still allow the fuzzer to call the unclamped handler with other addresses).

Clamping these values also doesn't overly restrict the search space because having random values passed in for users or tokens doesn't provide any benefit as they won't actually allow the fuzzer to reach additional states.

    Any time there are addresses representing users or addresses representing tokens in handler function calls we can clamp using the _getActor() and _getAsset() return values, respectively.

We can then run Echidna again to confirm whether this resolved our broken property as expected. After which we see that it still fails with the following reproducer:

    function test_property_totalSupplySolvency_1() public {
        rewardsManager_notifyTransfer(0x0000000000000000000000000000000000000000,1);

        vm.warp(block.timestamp + 701427);
        vm.roll(block.number + 1);
        rewardsManager_notifyTransfer(0x00000000000000000000000000000000DeaDBeef,0);

        vm.warp(block.timestamp + 512482);
        vm.roll(block.number + 1);
        property_totalSupplySolvency();
    }

This should be an indicator to us that our initial understanding of how the system works was incorrect and we now need to look at the notifyDeposit implementation again more in depth to determine why the property still breaks.

We can see from the reproducer test that in the calls to rewardsManager_notifyTransfer, the first call calls the internal \_handleDeposit function and the second call calls \_handleTransfer:

function notifyTransfer(address from, address to, uint256 amount) external {
...

        if (from == address(0)) {
            /// @audit this is called first with 1 amount
            _handleDeposit(msg.sender, to, amount);
        } else if (to == address(0)) {
            _handleWithdrawal(msg.sender, from, amount);
        } else {
            /// @audit this is called second with 0 amount
            _handleTransfer(msg.sender, from, to, amount);
        }

        ...

}

We can note that the first call is essentially registering a 1 wei deposit for the currently set actor (returned by \_getActor()) and the second call is registering a transfer of 0 from the 0x00000000000000000000000000000000DeaDBeef address to the currently set actor.

Since the rewardsManager_notifyTransfer(0x00000000000000000000000000000000DeaDBeef,0) call is the last one, we know that something in the \_handleTransfer call changes state in an unexpected way, which leads our property to break. Looking at the implementation of \_handleTransfer, we see that since we're passing in a 0 value, the only state-changing calls it makes are to accrueUser:

    function _handleTransfer(address vault, address from, address to, uint256 amount) internal {
        uint256 cachedCurrentEpoch = currentEpoch();
        // Accrue points for from, so they get rewards
        accrueUser(cachedCurrentEpoch, vault, from);
        // Accrue points for to, so they don't get too many rewards
        accrueUser(cachedCurrentEpoch, vault, to);

        /// @audit anything below these lines don't change state
        unchecked {
            // Add deposit data for to
            shares[cachedCurrentEpoch][vault][to] += amount;
        }

        // Delete deposit data for from
        shares[cachedCurrentEpoch][vault][from] -= amount;
    }

This indicates to us that we are accruing shares for the user if time has passed since the last update:

    function accrueUser(uint256 epochId, address vault, address user) public {
        require(epochId <= currentEpoch(), "only ended epochs");

        (uint256 currentBalance, bool shouldUpdate) = _getBalanceAtEpoch(epochId, vault, user);

        if(shouldUpdate) {
            shares[epochId][vault][user] = currentBalance;
        }

        ...
    }

Notably, however, there is no call to accrueVault in this transfer (unlike in the \_handleDeposit and \_handleWithdrawal functions), indicating that the user balances increase but the vault's totalSupply for the current epoch remains the same. We can then test whether this is the source of the issue by making a call to the accrueVault target handler:

    function test_property_totalSupplySolvency_1() public {
        rewardsManager_notifyTransfer(0x0000000000000000000000000000000000000000,1);

        vm.warp(block.timestamp + 701427);
        vm.roll(block.number + 1);
        rewardsManager_notifyTransfer(0x00000000000000000000000000000000DeaDBeef,0);

        rewardsManager_accrueVault(rewardsManager.currentEpoch(), address(this));

        vm.warp(block.timestamp + 512482);
        vm.roll(block.number + 1);
        property_totalSupplySolvency();
    }

which then allows the test to pass:

[PASS] test_property_totalSupplySolvency_1() (gas: 391567)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 7.33ms (2.83ms CPU time)

Looking at the accrueVault function, we see this is because it sets a new value for the totalSupply if the \_getTotalSupplyAtEpoch function determines that it hasn't updated since the last epoch:

function accrueVault(uint256 epochId, address vault) public {
require(epochId <= currentEpoch(), "Cannot see the future");

        (uint256 supply, bool shouldUpdate) = _getTotalSupplyAtEpoch(epochId, vault);

        if(shouldUpdate) {
            // Because we didn't return early, to make it cheaper for future lookbacks, let's store the lastKnownBalance
            totalSupply[epochId][vault] = supply;
        }

        ...

}

In our case, since there is no call to accrueVault in \_handleTransfer but there is a call to accrueUser, the user is accounted shares for the epoch, but the vault isn't.

We can say that this is a real bug because it causes users to have claimable shares in an epoch in which there are no claimable shares tracked by the total supply. This would cause the following logic in the claimReward function to behave incorrectly due to a 0 return value from \_getTotalSupplyAtEpoch, making a user unable to claim in an epoch for which they've accrued rewards:

    function claimReward(uint256 epochId, address vault, address token, address user) public {
        require(epochId < currentEpoch(), "only ended epochs");

        // Get balance for this epoch
        (uint256 userBalanceAtEpochId, ) = _getBalanceAtEpoch(epochId, vault, user);

        // Get user info for this epoch
        UserInfo memory userInfo = _getUserNextEpochInfo(epochId, vault, user, userBalanceAtEpochId);

        // If userPoints are zero, go next fast
        if (userInfo.userEpochTotalPoints == 0) {
            return; // Nothing to claim
        }

        /// @audit this would return 0 incorrectly
        (uint256 vaultSupplyAtEpochId, ) = _getTotalSupplyAtEpoch(epochId, vault);

        VaultInfo memory vaultInfo = _getVaultNextEpochInfo(epochId, vault, vaultSupplyAtEpochId);

        // To be able to use the same ratio for all tokens, we need the pointsWithdrawn to all be 0
        require(pointsWithdrawn[epochId][vault][user][token] == 0, "already claimed");

        // We got some stuff left // Use ratio to calculate what we got left
        uint256 totalAdditionalReward = rewards[epochId][vault][token];

        // Calculate tokens for user
        // @audit this would use the wrong value
        uint256 tokensForUser = totalAdditionalReward * userInfo.userEpochTotalPoints / vaultInfo.vaultEpochTotalPoints;

        ...
    }

Now that we've identified the source of the issue, we can add the additional call to the accrueVault function in \_handleTransfer:

    function _handleTransfer(address vault, address from, address to, uint256 amount) internal {
        uint256 cachedCurrentEpoch = currentEpoch();
        // Accrue points for from, so they get rewards
        accrueUser(cachedCurrentEpoch, vault, from);
        // Accrue points for to, so they don't get too many rewards
        accrueUser(cachedCurrentEpoch, vault, to);
        // @audit added accrual to vault so tracking is correct
        accrueVault(cachedCurrentEpoch, vault);

        ...
    }

We can then run the fuzzer again to confirm that our property now passes. After doing so, however, we see that it once again fails with the following reproducer:

// forge test --match-test test_property_totalSupplySolvency -vvv
function test_property_totalSupplySolvency() public {

    vm.warp(block.timestamp + 56523);
    vm.roll(block.number + 1);
    rewardsManager_notifyTransfer(0x0000000000000000000000000000000000000000,1);

    switchActor(25183731206506529133541749133319);

    vm.warp(block.timestamp + 947833);
    vm.roll(block.number + 1);
    rewardsManager_notifyTransfer(0x0000000000000000000000000000000000000000,0);

    vm.warp(block.timestamp + 206328);
    vm.roll(block.number + 1);
    property_totalSupplySolvency();

}

which upon further investigation reveals that the call from notifyTransfer to \_handleDeposit with a 0 value for amount causes the totalSupply to accrue for the vault but not the user since they have no value deposited:

    function _handleDeposit(address vault, address to, uint256 amount) internal {
        uint256 cachedCurrentEpoch = currentEpoch();
        // @audit this accrues nothing since the actor that's switched to has no deposits
        accrueUser(cachedCurrentEpoch, vault, to);
        // @audit this accrues totalSupply with the amount deposited by the first actor
        accrueVault(cachedCurrentEpoch, vault);

        ...
    }

This should then cause us to reason that if we have a totalSupply greater than or equal to the shares accounted to users, then the system is solvent and able to repay all depositors, but if we have less than this amount, the system would be unable to repay all depositors. Which means that our property broke when it shouldn't have and so we can refactor it accordingly:

    function property_totalSupplySolvency() public {
        uint256 currentEpoch = rewardsManager.currentEpoch();
        uint256 epoch;

        while(epoch < currentEpoch) {
            uint256 sharesAtEpoch;

            // sum over all users
            for (uint256 i = 0; i < _getActors().length; i++) {
                uint256 shares = rewardsManager.shares(epoch, address(this), _getActors()[i]);
                sharesAtEpoch += shares;
            }

            // check if solvency is met
            lte(sharesAtEpoch, rewardsManager.totalSupply(epoch, address(this)), "Sum of user shares should equal total supply");

            epoch++;
        }

    }

where our property now uses a less than or equal assertion (lte) instead of strict equality (eq), allowing the sum of user shares for an epoch to be less than the totalSupply for that epoch.

After running the fuzzer with this new property implementation for 5-10 minutes, it holds, confirming that it's now properly implemented.

The implementation property of the second property is left as an exercise to the reader, you can use the pseudocode to guide you and it should follow a similar implementation pattern as the first.
Conclusion

We've seen how invariant testing can often highlight misunderstandings of a system by giving you ways to easily test assumptions that are difficult to test with unit tests or stateless fuzzing. When these assumptions fail, it's either due to a false positive or a misunderstanding of how the system works, or both, as we saw above.

When you're forced to refactor your code to resolve an issue identified by a broken property, you can then run the fuzzer to confirm whether you resolved the issue for all cases. As we saw above this allowed us to see that our property implementation was overly strict and could be modified to be less strict.

One of the other key benefits of invariant testing besides explicitly identifying exploits is that it allows you to ask and answer questions about whether it's possible to get the system into a specific state. If the answer is yes and the state is unexpected, this can often be used as a precondition that can lead to an exploit of the system.

In part 4, we'll look at how a precondition was able to identify a multi-million dollar bug in a real-world codebase before it was pushed to production.

As always, if you have any questions reach out to the Recon team in the help channel of our discord.

Recon Logo

    Introduction
    Writing Invariant Tests
    1. Learn Invariant Testing
    2. Example Project
    3. Implementing Properties
    4. Optimizing Broken Properties
    5. Advanced Fuzzing Tips
    6. Chimera Framework
    7. Create Chimera App
    Bootcamp
    8. Intro to the Bootcamp
    9. Part 1 - Invariant Testing with Chimera Framework
    10. Part 2 - Multidimensional Invariant Tests
    11. Part 3 - Writing and Breaking Properties
    12. Part 4 - Liquity Governance Case Study
    Using Recon
    13. Getting Started
    14. Upgrading to Pro
    15. Building Handlers
    16. Running Jobs
    17. Recon Magic
    18. Recipes
    19. Alerts
    20. Campaigns
    21. Dynamic Replacement
    22. Governance Fuzzing
    23. Recon Tricks
    Free Recon Tools
    24. Recon Extension
    25. Medusa Log Scraper
    26. Echidna Log Scraper
    27. Handler Builder
    28. Bytecode Compare
    29. Bytecode To Interface
    30. Bytecode Static Deployment
    31. Bytecode Formatter
    32. String To Bytes
    33. OpenZeppelin Roles Scraper
    OSS Repos
    34. Chimera
    35. Create Chimera App
    36. Log Parser
    37. ABI to Invariants
    38. ABI to Mock
    39. Setup Helpers
    40. Properties Table
    41. ERC7540 Reusable Properties
    OpSec
    42. OpSec Resources
    Help
    43. Glossary

Recon Book
Part 4 - Liquity Governance Case Study

In part 4 we'll see how everything we've covered up to this point in the bootcamp was used to find a real-world vulnerability in Liquity's governance system in an engagement performed by Alex The Entreprenerd. We'll also see how to use Echidna's optimization mode to increase the severity of a vulnerability.

This issue was found in this commit of the Liquity V2 codebase which was under review which you can clone if you'd like to follow along and reproduce the test results locally as it already contains all the scaffolding and property implementations.

    For the recorded stream of this part of the bootcamp see here starting at 49:40.

Background on Liquity Governance V2

The Liquity V2 Governance system is a modular initiative-based governance mechanism where users stake LQTY tokens to earn voting power that accrues linearly over time, where the longer the user is staked, the greater their voting power. Users then allocate this voting power to fund various "initiatives" (any smart contract implementing IInitiative interface) that compete for a share of protocol revenues (25% of Liquity's income) distributed weekly through 7-day epochs.
Calculate average timestamp

A key aspect of accruing voting power to a user is the mechanism that was chosen to determine the amount of time which a user had their LQTY allocated. In this case this was handled by the \_calculateAverageTimestamp function:

    function _calculateAverageTimestamp(
        uint120 _prevOuterAverageTimestamp,
        uint120 _newInnerAverageTimestamp,
        uint88 _prevLQTYBalance,
        uint88 _newLQTYBalance
    ) internal view returns (uint120) {
        if (_newLQTYBalance == 0) return 0;

        uint120 currentTime = uint120(uint32(block.timestamp)) * uint120(TIMESTAMP_PRECISION);

        uint120 prevOuterAverageAge = _averageAge(currentTime, _prevOuterAverageTimestamp);
        uint120 newInnerAverageAge = _averageAge(currentTime, _newInnerAverageTimestamp);

        uint208 newOuterAverageAge;
        if (_prevLQTYBalance <= _newLQTYBalance) {
            uint88 deltaLQTY = _newLQTYBalance - _prevLQTYBalance;
            uint208 prevVotes = uint208(_prevLQTYBalance) * uint208(prevOuterAverageAge);
            uint208 newVotes = uint208(deltaLQTY) * uint208(newInnerAverageAge);
            uint208 votes = prevVotes + newVotes;
            // @audit truncation happens here
            newOuterAverageAge = votes / _newLQTYBalance;
        } else {
            uint88 deltaLQTY = _prevLQTYBalance - _newLQTYBalance;
            uint208 prevVotes = uint208(_prevLQTYBalance) * uint208(prevOuterAverageAge);
            uint208 newVotes = uint208(deltaLQTY) * uint208(newInnerAverageAge);
            uint208 votes = (prevVotes >= newVotes) ? prevVotes - newVotes : 0;
            // @audit truncation happens here
            newOuterAverageAge = votes / _newLQTYBalance;
        }

        if (newOuterAverageAge > currentTime) return 0;
        return uint120(currentTime - newOuterAverageAge);
    }

The intention of all this added complexity was to prevent flashloans from manipulating voting power by using the average amount of time for which a user was deposited to calculate voting power. In the case of a flashloan since the user has to deposit and withdraw within the same transaction their average deposited time would be 0 resulting in the lqtyToVotes calculation, used to calculate voting power, also returning 0:

    function lqtyToVotes(uint88 _lqtyAmount, uint120 _currentTimestamp, uint120 _averageTimestamp)
        public
        pure
        returns (uint208)
    {
        return uint208(_lqtyAmount) * uint208(_averageAge(_currentTimestamp, _averageTimestamp));
    }

The key thing to note for our case is that the newOuterAverageAge calculation is subject to truncation because of the division operation that it performs. This had been highlighted in a previous review and it had been thought that the maximum value lost to truncation would be 1 second, since the newOuterAverageAge represents time in seconds and the truncation would essentially act as a rounding down, eliminating the trailing digit. Since the maximum lost value was 1 second, the impact of this finding was judged as low severity because it would only minimally affect voting power by undervaluing the time for which users were deposited.

More specifically, if we look at the \_allocateLQTY function, which makes the call to \_calculateAverageTimestamp and actually handles user vote allocation using the LQTY token, we see the following:

    function _allocateLQTY(
        address[] memory _initiatives,
        int88[] memory _deltaLQTYVotes,
        int88[] memory _deltaLQTYVetos
    ) internal {
        ...

            // update the average staking timestamp for the initiative based on the user's average staking timestamp
            initiativeState.averageStakingTimestampVoteLQTY = _calculateAverageTimestamp(
                initiativeState.averageStakingTimestampVoteLQTY,
                userState.averageStakingTimestamp,
                initiativeState.voteLQTY,
                add(initiativeState.voteLQTY, deltaLQTYVotes) // @audit modifies LQTY allocation for user
            );
            initiativeState.averageStakingTimestampVetoLQTY = _calculateAverageTimestamp(
                initiativeState.averageStakingTimestampVetoLQTY,
                userState.averageStakingTimestamp,
                initiativeState.vetoLQTY,
                add(initiativeState.vetoLQTY, deltaLQTYVetos) // @audit modifies LQTY allocation for user
            );
    }

So the user's LQTY allocation directly impacts the averageStakingTimestamp and the votes associated with each user.

In the case where \_prevLQTYBalance > \_newLQTYBalance, indicating a user was decreasing their allocation:

    function _calculateAverageTimestamp(
        uint120 _prevOuterAverageTimestamp,
        uint120 _newInnerAverageTimestamp,
        uint88 _prevLQTYBalance,
        uint88 _newLQTYBalance
    ) internal view returns (uint120) {
        ...

        uint208 newOuterAverageAge;
        if (_prevLQTYBalance <= _newLQTYBalance) {
            ...
        } else {
            uint88 deltaLQTY = _prevLQTYBalance - _newLQTYBalance;
            uint208 prevVotes = uint208(_prevLQTYBalance) * uint208(prevOuterAverageAge);
            uint208 newVotes = uint208(deltaLQTY) * uint208(newInnerAverageAge);
            uint208 votes = (prevVotes >= newVotes) ? prevVotes - newVotes : 0;
            // @audit truncation up to 1 second occurs here
            newOuterAverageAge = votes / _newLQTYBalance;
        }

        if (newOuterAverageAge > currentTime) return 0;
        return uint120(currentTime - newOuterAverageAge);
    }

and with the recognition of the 1 second truncation, an attacker could grief an initiative by removing an amount of allocated LQTY, which would cause their newOuterAverageAge to decrease by less than it should. As a result the attacker maintains more voting power than they should, subsequently diluting the voting power of other voters.
The property that revealed the truth

To fully explore this and determine whether the maximum severity of the issue was in fact only minimal griefing with a max difference of 1 second, the following property was implemented:

    function property_sum_of_initatives_matches_total_votes_strict() public {
        // Sum up all initiatives
        // Compare to total votes
        (uint256 allocatedLQTYSum, uint256 totalCountedLQTY, uint256 votedPowerSum, uint256 govPower) = _getInitiativeStateAndGlobalState();

        eq(allocatedLQTYSum, totalCountedLQTY, "LQTY Sum of Initiative State matches Global State at all times");
        eq(votedPowerSum, govPower, "Voting Power Sum of Initiative State matches Global State at all times");
    }

which simply checked that the sum of allocated LQTY for all initiatives is equivalent to the total allocated LQTY in the system and that the sum of voting power for all initiatives is equivalent to the total voting power in the system.

The following helper function was used to help with this comparison:

    function _getInitiativeStateAndGlobalState() internal returns (uint256, uint256, uint256, uint256) {
        (
            uint88 totalCountedLQTY,
            uint120 global_countedVoteLQTYAverageTimestamp
        ) = governance.globalState();

        // Global Acc
        // Initiative Acc
        uint256 allocatedLQTYSum;
        uint256 votedPowerSum;
        for (uint256 i; i < deployedInitiatives.length; i++) {
            (
                uint88 voteLQTY,
                uint88 vetoLQTY,
                uint120 averageStakingTimestampVoteLQTY,
                uint120 averageStakingTimestampVetoLQTY,

            ) = governance.initiativeStates(deployedInitiatives[i]);

            // Conditional, only if not DISABLED
            (Governance.InitiativeStatus status,,) = governance.getInitiativeState(deployedInitiatives[i]);
            // Conditionally add based on state
            if (status != Governance.InitiativeStatus.DISABLED) {
                allocatedLQTYSum += voteLQTY;
                // Sum via projection
                votedPowerSum += governance.lqtyToVotes(voteLQTY, uint120(block.timestamp) * uint120(governance.TIMESTAMP_PRECISION()), averageStakingTimestampVoteLQTY);
            }

        }

        uint256 govPower = governance.lqtyToVotes(totalCountedLQTY, uint120(block.timestamp) * uint120(governance.TIMESTAMP_PRECISION()), global_countedVoteLQTYAverageTimestamp);

        return (allocatedLQTYSum, totalCountedLQTY, votedPowerSum, govPower);
    }

by performing the operation to sum the amount of allocated LQTY and voting power for all initiatives. This also provides the global state by fetching it directly from the governance contract.
Escalating from low to critical severity

After running the fuzzer on the property, it was found to break, which led to two possible paths for what to do next: identify exactly why the property breaks (this was already known so not necessarily beneficial in escalating the severity), or introduce a tolerance by which the strict equality in the two values being compared could differ.

Given that the \_calculateAverageTimestamp function was expected to have a maximum of 1 second variation, the approach of allowing a tolerance in a separate property was used to determine whether the variation was ever greater than this:

    function property_sum_of_initatives_matches_total_votes_bounded() public {
        // Sum up all initiatives
        // Compare to total votes
        (uint256 allocatedLQTYSum, uint256 totalCountedLQTY, uint256 votedPowerSum, uint256 govPower) = _getInitiativeStateAndGlobalState();

        t(
            allocatedLQTYSum == totalCountedLQTY || (
                allocatedLQTYSum >= totalCountedLQTY - TOLERANCE &&
                allocatedLQTYSum <= totalCountedLQTY + TOLERANCE
            ),
        "Sum of Initiative LQTY And State matches within absolute tolerance");

        t(
            votedPowerSum == govPower || (
                votedPowerSum >= govPower - TOLERANCE &&
                votedPowerSum <= govPower + TOLERANCE
            ),
        "Sum of Initiative LQTY And State matches within absolute tolerance");
    }

where TOLERANCE is the voting power for 1 second, given by LQTY \* 1 Second where LQTY is a value in with 18 decimal precision:

    uint256 constant TOLERANCE = 1e19;

which meant that our TOLERANCE value would allow up to 10 seconds of lost allocated time in the average calculation, anything beyond this would again break the property. We use 10 seconds in this case because if we used 1 second as the tolerance the fuzzer would most likely break the property for values less than 10, still making this only a griefing issue, however if it breaks for more than 10 seconds we know we have something more interesting worth exploring further.

Surely enough, after running the fuzzer again with this tolerance added, it once again broke the property, indicating that the initial classification as a low severity issue that would only be restricted to a 1 second difference was incorrect and now this would require further investigation to understand the maximum possible impact. To find the maximum possible impact we could then create a test using Echidna's optimization mode.
Using optimization mode

Converting properties into an optimization mode test is usually just a matter of slight refactoring to the existing property to instead return some value rather than make an assertion:

    function optimize_property_sum_of_initatives_matches_total_votes_insolvency() public returns (int256) {
        int256 max = 0;

        (, , uint256 votedPowerSum, uint256 govPower) = _getInitiativeStateAndGlobalState();

        if(votedPowerSum > govPower) {
            max = int256(votedPowerSum) - int256(govPower);
        }

        return max;
    }

where we can see that we just return the maximum value as the difference of int256(votedPowerSum) - int256(govPower) if votedPowerSum > govPower. Echidna will then use all the existing target function handlers to manipulate state in an attempt to optimize the value returned by this function.

    For more on how to define optimization properties, checkout this page.

This test could then be run using the echidna . --contract CryticTester --config echidna.yaml --format text --test-limit 10000000 --test-mode optimization command or by selecting optimization mode in the Recon cockpit.
The revelation and impact

After running the fuzzer for 100 million tests, we get the following unit test generated from the reproducer:

// forge test --match-test test_optimize_property_sum_of_initatives_matches_total_votes_insolvency_0 -vvv
function test_optimize_property_sum_of_initatives_matches_total_votes_insolvency_0() public {

    // Max value: 4152241824275924884020518;

    vm.prank(0x0000000000000000000000000000000000010000);
    property_sum_of_lqty_global_user_matches();

    vm.warp(block.timestamp + 4174);

    vm.roll(block.number + 788);

    vm.roll(block.number + 57);
    vm.warp(block.timestamp + 76299);
    vm.prank(0x0000000000000000000000000000000000010000);
    governance_withdrawLQTY_shouldRevertWhenClamped(15861774047245688283806176);

    vm.roll(block.number + 4288);
    vm.warp(block.timestamp + 419743);
    vm.prank(0x0000000000000000000000000000000000010000);
    governance_depositLQTY_2(2532881971795689134446062);

    vm.roll(block.number + 38154);
    vm.warp(block.timestamp + 307412);
    vm.prank(0x0000000000000000000000000000000000010000);
    governance_allocateLQTY_clamped_single_initiative_2nd_user(27,211955987,0);

    vm.prank(0x0000000000000000000000000000000000010000);
    property_shouldNeverRevertsecondsWithinEpoch();

    vm.warp(block.timestamp + 113902);

    vm.roll(block.number + 4968);

    vm.roll(block.number + 8343);
    vm.warp(block.timestamp + 83004);
    vm.prank(0x0000000000000000000000000000000000010000);
    governance_claimForInitiative(68);

    vm.prank(0x0000000000000000000000000000000000010000);
    check_realized_claiming_solvency();

    vm.roll(block.number + 2771);
    vm.warp(block.timestamp + 444463);
    vm.prank(0x0000000000000000000000000000000000010000);
    check_claim_soundness();

    vm.warp(block.timestamp + 643725);

    vm.roll(block.number + 17439);

    vm.prank(0x0000000000000000000000000000000000010000);
    property_shouldNeverRevertsnapshotVotesForInitiative(108);

    vm.roll(block.number + 21622);
    vm.warp(block.timestamp + 114917);
    vm.prank(0x0000000000000000000000000000000000010000);
    governance_depositLQTY(999999999999999999998);

    vm.roll(block.number + 1746);
    vm.warp(block.timestamp + 21);
    vm.prank(0x0000000000000000000000000000000000010000);
    governance_depositLQTY(12);

    vm.prank(0x0000000000000000000000000000000000010000);
    property_shouldNeverRevertepochStart(250);

    vm.roll(block.number + 49125);
    vm.warp(block.timestamp + 190642);
    vm.prank(0x0000000000000000000000000000000000010000);
    property_shouldNeverRevertSnapshotAndState(2);

    vm.prank(0x0000000000000000000000000000000000010000);
    property_shouldNeverRevertsecondsWithinEpoch();

    vm.prank(0x0000000000000000000000000000000000010000);
    property_shouldNeverRevertsecondsWithinEpoch();

    vm.roll(block.number + 18395);
    vm.warp(block.timestamp + 339084);
    vm.prank(0x0000000000000000000000000000000000010000);
    governance_allocateLQTY_clamped_single_initiative(81,797871,0);

    vm.prank(0x0000000000000000000000000000000000010000);
    property_initiative_ts_matches_user_when_non_zero();

    vm.warp(block.timestamp + 468186);

    vm.roll(block.number + 16926);

    vm.prank(0x0000000000000000000000000000000000010000);
    helper_deployInitiative();

    vm.prank(0x0000000000000000000000000000000000010000);
    property_BI05();

    vm.prank(0x0000000000000000000000000000000000010000);
    property_sum_of_user_voting_weights_strict();

    vm.roll(block.number + 60054);
    vm.warp(block.timestamp + 431471);
    vm.prank(0x0000000000000000000000000000000000010000);
    property_sum_of_user_voting_weights_strict();

    vm.warp(block.timestamp + 135332);

    vm.roll(block.number + 38421);

    vm.roll(block.number + 7278);
    vm.warp(block.timestamp + 455887);
    vm.prank(0x0000000000000000000000000000000000010000);
    property_allocations_are_never_dangerously_high();

    vm.roll(block.number + 54718);
    vm.warp(block.timestamp + 58);
    vm.prank(0x0000000000000000000000000000000000010000);
    property_shouldNeverRevertsecondsWithinEpoch();

    vm.prank(0x0000000000000000000000000000000000010000);
    governance_snapshotVotesForInitiative(0xE8E23e97Fa135823143d6b9Cba9c699040D51F70);

    vm.prank(0x0000000000000000000000000000000000010000);
    property_shouldGetTotalVotesAndState();

    vm.prank(0x0000000000000000000000000000000000010000);
    initiative_depositBribe(20,94877931099225030012957476263093446259,62786,38);

    vm.prank(0x0000000000000000000000000000000000010000);
    governance_withdrawLQTY_shouldRevertWhenClamped(72666608067123387567523936);

    vm.roll(block.number + 17603);
    vm.warp(block.timestamp + 437837);
    vm.prank(0x0000000000000000000000000000000000010000);
    helper_deployInitiative();

    vm.roll(block.number + 6457);
    vm.warp(block.timestamp + 349998);
    vm.prank(0x0000000000000000000000000000000000010000);
    property_allocations_are_never_dangerously_high();

    vm.roll(block.number + 49513);
    vm.warp(block.timestamp + 266623);
    vm.prank(0x0000000000000000000000000000000000010000);
    helper_accrueBold(29274205);

    vm.prank(0x0000000000000000000000000000000000010000);
    governance_registerInitiative(62);

    vm.prank(0x0000000000000000000000000000000000010000);
    governance_claimForInitiative(81);

    vm.prank(0x0000000000000000000000000000000000030000);
    property_shouldNeverRevertepochStart(128);

    vm.roll(block.number + 7303);
    vm.warp(block.timestamp + 255335);
    vm.prank(0x0000000000000000000000000000000000010000);
    governance_claimForInitiativeDoesntRevert(15);

    vm.prank(0x0000000000000000000000000000000000010000);
    initiative_depositBribe(216454974247908041355937489573535140507,24499346771823261073415684795094302253,10984,12);

    vm.prank(0x0000000000000000000000000000000000010000);
    governance_allocateLQTY_clamped_single_initiative(74,5077,0);

    vm.prank(0x0000000000000000000000000000000000010000);
    property_GV01();

    vm.warp(block.timestamp + 427178);

    vm.roll(block.number + 4947);

    vm.roll(block.number + 43433);
    vm.warp(block.timestamp + 59769);
    vm.prank(0x0000000000000000000000000000000000010000);
    governance_withdrawLQTY_shouldRevertWhenClamped(48);

}

indicating that the initial insolvency was a severe underestimate, allowing a possible inflation in voting power of 4152241824275924884020518 / 1e18 = 4,152,241. When translated into the dollar equivalent of LQTY, this results in millions of dollars worth of possible inflation in voting power.

It's worth noting that if we let Echidna run for even longer, we would see that it subsequently inflates the voting power even further as was done in the engagement, which demonstrated an inflation in the range of hundreds of millions of dollars.

The dilemma of when to stop a test run is a common one when using optimization mode as it can often find continuously larger and larger values the longer you allow the fuzzer to run. Typically however there is a point of diminishing returns where the value is sufficiently maximized to prove a given severity. In this case, for example, maximizing any further wouldn't increase the severity as the value above already demonstrates a critical severity issue.

    For more info about how to generate a shrunken reproducer with optimization mode see this section

So what was originally thought to just be a precision loss of 1 second really turned out to be one second for all stake for each initiative, meaning that this value is very large once you have a large amount of voting power and many seconds have passed. This could then be applied to every initiative, inflating voting power even further.
Conclusion

Fundamentally, a global property breaking should be a cause for pause, which you should use to reflect and consider further how the system works. Then you can determine the severity of the broken property using the three steps shown above: an exact check, an exact check with bounds, and optimization mode.

More generally, if you can't use an exact check to check your property and have to use greater than or less than instead, you can refactor the implementation into an optimization mode test to determine what the maximum possible difference is.
Next steps

This concludes the Recon bootcamp. You should now be ready to take everything you've learned here and apply it to real-world projects to find bugs with invariant testing.

To learn more about techniques for implementing properties, check out this section. For more on how to use optimization mode to determine the maximum severity of a broken property, check out this section.

For some real-world examples of how we used Chimera to set up invariant testing suites for some of our customers, check out the following repos from Recon engagements:

    eBTC BSM
    Nerite
    Liquity Governance V2

If you have any questions or feel that we've missed a topic to help you get started with invariant testing, please reach out to the Recon team in the help channel of our Discord.
