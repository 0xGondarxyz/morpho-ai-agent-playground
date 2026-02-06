// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

// Managers
import {ActorManager} from "@recon/ActorManager.sol";
import {AssetManager} from "@recon/AssetManager.sol";

// Helpers
import {Utils} from "@recon/Utils.sol";
import {MockERC20} from "@recon/MockERC20.sol";

// Your deps
import "src/Morpho.sol";
import {IMorpho} from "src/interfaces/IMorpho.sol";

//import mock contracts
import {FlashBorrowerMock} from "src/mocks/FlashBorrowerMock.sol";
import {IrmMock} from "src/mocks/IrmMock.sol";
import {OracleMock} from "src/mocks/OracleMock.sol";

//import libs
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
    // using MarketParamsLib for MarketParams;

    Morpho morpho;
    FlashBorrowerMock flashBorrower;
    IrmMock irm;
    OracleMock oracle;
    IMorpho iMorpho;
    MarketParams marketParams;

    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        morpho = new Morpho(_getActor());
        irm = new IrmMock();
        oracle = new OracleMock();
        iMorpho = IMorpho(address(morpho));
        flashBorrower = new FlashBorrowerMock(iMorpho);

        //set oracle price
        oracle.setPrice(1e36);

        // Add 3 actors
        _addActor(address(0x411c3));
        _addActor(address(0x411c4));
        _addActor(address(0x411c5));

        // Deploy assets
        _newAsset(18); // collateral token
        _newAsset(18); // loan token

        // Mint tokens and approve to morpho for all actors
        address[] memory approvalArray = new address[](1);
        approvalArray[0] = address(morpho);
        _finalizeAssetDeployment(_getActors(), approvalArray, type(uint88).max);

        // Create the market
        morpho.enableIrm(address(irm));
        morpho.enableLltv(8e17);

        address[] memory assets = _getAssets();
        marketParams = MarketParams({
            loanToken: assets[1], collateralToken: assets[0], oracle: address(oracle), irm: address(irm), lltv: 8e17
        });
        morpho.createMarket(marketParams);
    }

    /// === Dynamic deploy helpers === ///

    /// === MODIFIERS === ///
    /// Prank admin and actor

    modifier asAdmin() {
        vm.startPrank(address(this));
        _;
        vm.stopPrank();
    }

    modifier asActor() {
        vm.startPrank(address(_getActor()));
        _;
        vm.stopPrank();
    }
}
