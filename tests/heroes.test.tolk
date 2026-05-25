import "@acton/build"
import "@acton/emulation/network"
import "@acton/emulation/testing"
import "@acton/testing/expect"
import "@acton/types/array"

import "@contracts/errors"
import "@contracts/messages"
import "@contracts/types"
import "@wrappers/NftCollection.gen"
import "@wrappers/NftItem.gen"

get fun `test hero: admin deploy hero`() {
    val (nftCollection, deployer, _) = setupTest();
    val nextItemIndex = nftCollection.getCollectionData().nextItemIndex;
    val ownerAddress = randomAddress();
    
    val stats: SpecialStats = {
        strength: 5,
        perception: 5,
        endurance: 5,
        charisma: 5,
        intelligence: 5,
        agility: 5,
        luck: 5,
    };
    
    val initParams: HeroInitParams = {
        ownerAddress,
        content: "0.json",
        level: 10,
        xpInvested: 1000,
        freeStatPoints: 5,
        isTransferable: true,
        specialStats: stats.toCell(),
    };

    val result = nftCollection.sendDeployHero(
        deployer.address,
        0,
        nextItemIndex,
        ton("0.02"),
        initParams,
        { value: ton("0.05"), bounce: true },
    );

    expect(result).toHaveSuccessfulTx<DeployHero>({
        from: deployer.address,
        to: nftCollection.address,
    });

    val nftAddress = nftCollection.getNftAddressByIndex(nextItemIndex);
    
    expect(result).toHaveSuccessfulDeploy({
        from: nftCollection.address,
        to: nftAddress,
    });

    val nftItem = NftItem.fromAddress(nftAddress);
    val heroProps = nftItem.getHeroProperties();

    expect(heroProps.level).toEqual(10);
    expect(heroProps.xpInvested).toEqual(1000);
    expect(heroProps.freeStatPoints).toEqual(5);
    expect(heroProps.isTransferable).toEqual(1);
    expect(heroProps.specialStats.strength as int).toEqual(5);
    expect(heroProps.specialStats.luck as int).toEqual(5);
}

get fun `test hero: public mint hero generates random stats`() {
    val (nftCollection, _, user) = setupTest();
    val nextItemIndex = nftCollection.getCollectionData().nextItemIndex;

    val result = nftCollection.sendPublicMintHero(
        user.address,
        0,
        { value: ton("1.2"), bounce: true },
    );

    expect(result).toHaveSuccessfulTx<PublicMintHero>({
        from: user.address,
        to: nftCollection.address,
    });

    val nftAddress = nftCollection.getNftAddressByIndex(nextItemIndex);

    expect(result).toHaveSuccessfulDeploy({
        from: nftCollection.address,
        to: nftAddress,
    });

    val nftItem = NftItem.fromAddress(nftAddress);
    val heroProps = nftItem.getHeroProperties();

    // Verify initial values
    expect(heroProps.level).toEqual(1);
    expect(heroProps.xpInvested).toEqual(0);
    expect(heroProps.freeStatPoints).toEqual(0);
    expect(heroProps.isTransferable).toEqual(1);

    // Sum of SPECIAL stats should be exactly 35 (7 * 1 + 28 distributed points)
    val stats = heroProps.specialStats;
    val sum = (stats.strength as int)
        + (stats.perception as int)
        + (stats.endurance as int)
        + (stats.charisma as int)
        + (stats.intelligence as int)
        + (stats.agility as int)
        + (stats.luck as int);
    expect(sum).toEqual(35);
}

get fun `test hero: public mint fails if not enough ton`() {
    val (nftCollection, _, user) = setupTest();

    val result = nftCollection.sendPublicMintHero(
        user.address,
        0,
        { value: ton("1.0"), bounce: true }, // Not enough (1.0 < 1.0 + 0.15)
    );

    expect(result).toHaveFailedTx<PublicMintHero>({
        from: user.address,
        to: nftCollection.address,
        exitCode: Errors.InsufficientFunds,
    });
}

get fun `test hero: admin can update levels and stats`() {
    val (nftCollection, deployer, user) = setupTest();
    
    // 1. Deploy hero first
    val nextItemIndex = nftCollection.getCollectionData().nextItemIndex;
    val stats: SpecialStats = {
        strength: 5, perception: 5, endurance: 5, charisma: 5, intelligence: 5, agility: 5, luck: 5
    };
    val initParams: HeroInitParams = {
        ownerAddress: user.address,
        content: "0.json",
        level: 1,
        xpInvested: 0,
        freeStatPoints: 0,
        isTransferable: true,
        specialStats: stats.toCell(),
    };
    nftCollection.sendDeployHero(
        deployer.address,
        0,
        nextItemIndex,
        ton("0.02"),
        initParams,
        { value: ton("0.05"), bounce: true },
    );
    val nftAddress = nftCollection.getNftAddressByIndex(nextItemIndex);
    val nftItem = NftItem.fromAddress(nftAddress);

    // 2. Admin updates the level and stats
    val newStats: SpecialStats = {
        strength: 10, perception: 5, endurance: 5, charisma: 5, intelligence: 5, agility: 5, luck: 10
    };
    val updateResult = nftCollection.sendAskToUpdateHero(
        deployer.address,
        0,
        nextItemIndex,
        50, // level
        100000, // xp
        10, // freeStatPoints
        newStats,
        deployer.address, // sendExcessesTo
        { value: ton("0.05"), bounce: true },
    );

    expect(updateResult).toHaveSuccessfulTx<AskToUpdateHero>({
        from: deployer.address,
        to: nftCollection.address,
    });

    expect(updateResult).toHaveSuccessfulTx<UpdateHero>({
        from: nftCollection.address,
        to: nftAddress,
    });

    val heroProps = nftItem.getHeroProperties();
    expect(heroProps.level).toEqual(50);
    expect(heroProps.xpInvested).toEqual(100000);
    expect(heroProps.freeStatPoints).toEqual(10);
    expect(heroProps.specialStats.strength as int).toEqual(10);
    expect(heroProps.specialStats.luck as int).toEqual(10);
}

get fun `test hero: hacker cannot update levels`() {
    val (nftCollection, deployer, user) = setupTest();
    val nextItemIndex = nftCollection.getCollectionData().nextItemIndex;
    
    // Deploy hero
    val stats: SpecialStats = {
        strength: 5, perception: 5, endurance: 5, charisma: 5, intelligence: 5, agility: 5, luck: 5
    };
    val initParams: HeroInitParams = {
        ownerAddress: user.address,
        content: "0.json",
        level: 1,
        xpInvested: 0,
        freeStatPoints: 0,
        isTransferable: true,
        specialStats: stats.toCell(),
    };
    nftCollection.sendDeployHero(
        deployer.address,
        0,
        nextItemIndex,
        ton("0.02"),
        initParams,
        { value: ton("0.05"), bounce: true },
    );
    val nftAddress = nftCollection.getNftAddressByIndex(nextItemIndex);
    val nftItem = NftItem.fromAddress(nftAddress);

    // User (hacker) attempts to update the level via collection
    val fakeStats: SpecialStats = {
        strength: 99, perception: 5, endurance: 5, charisma: 5, intelligence: 5, agility: 5, luck: 5
    };
    val result1 = nftCollection.sendAskToUpdateHero(
        user.address,
        0,
        nextItemIndex,
        100,
        999999,
        0,
        fakeStats,
        user.address,
        { value: ton("0.05"), bounce: true },
    );

    expect(result1).toHaveFailedTx<AskToUpdateHero>({
        from: user.address,
        to: nftCollection.address,
        exitCode: Errors.NotFromAdmin,
    });

    // User attempts to send UpdateHero directly to the item (hacking)
    val result2 = nftItem.sendUpdateHero(
        user.address,
        0,
        100,
        999999,
        0,
        fakeStats,
        user.address,
        { value: ton("0.05"), bounce: true },
    );

    expect(result2).toHaveFailedTx<UpdateHero>({
        from: user.address,
        to: nftAddress,
        exitCode: Errors.NotFromCollection,
    });
}

get fun `test hero: transferable locks transfers`() {
    val (nftCollection, deployer, user) = setupTest();
    val nextItemIndex = nftCollection.getCollectionData().nextItemIndex;
    
    // Deploy non-transferable hero
    val stats: SpecialStats = {
        strength: 5, perception: 5, endurance: 5, charisma: 5, intelligence: 5, agility: 5, luck: 5
    };
    val initParams: HeroInitParams = {
        ownerAddress: user.address,
        content: "0.json",
        level: 1,
        xpInvested: 0,
        freeStatPoints: 0,
        isTransferable: false, // LOCK TRANSFER!
        specialStats: stats.toCell(),
    };
    nftCollection.sendDeployHero(
        deployer.address,
        0,
        nextItemIndex,
        ton("0.02"),
        initParams,
        { value: ton("0.05"), bounce: true },
    );
    val nftAddress = nftCollection.getNftAddressByIndex(nextItemIndex);
    val nftItem = NftItem.fromAddress(nftAddress);

    // Try to transfer
    val receiver = randomAddress();
    val transferResult = nftItem.sendAskToChangeOwnership(
        user.address,
        0,
        receiver,
        user.address,
        null,
        0,
        PayloadInline { value: beginCell().storeUint(0, 1).endCell().beginParse() as unknown as RemainingBitsAndRefs },
        { value: ton("0.05"), bounce: true },
    );

    expect(transferResult).toHaveFailedTx<AskToChangeOwnership>({
        from: user.address,
        to: nftAddress,
        exitCode: Errors.TransferIsLocked,
    });
}

get fun `test collection: admin can upgrade collection`() {
    val (nftCollection, deployer, _) = setupTest();
    
    val newCode = build("NftCollection");
    val upgradeResult = nftCollection.sendUpgradeCollection(
        deployer.address,
        0,
        newCode,
        null,
        { value: ton("0.05"), bounce: true },
    );

    expect(upgradeResult).toHaveSuccessfulTx<UpgradeCollection>({
        from: deployer.address,
        to: nftCollection.address,
    });
}

get fun `test collection: hacker cannot upgrade collection`() {
    val (nftCollection, _, user) = setupTest();
    
    val newCode = build("NftCollection");
    val upgradeResult = nftCollection.sendUpgradeCollection(
        user.address,
        0,
        newCode,
        null,
        { value: ton("0.05"), bounce: true },
    );

    expect(upgradeResult).toHaveFailedTx<UpgradeCollection>({
        from: user.address,
        to: nftCollection.address,
        exitCode: Errors.NotFromAdmin,
    });
}

fun setupTest(): (NftCollection, Treasury, Treasury) {
    val deployer = testing.treasury("deployer");
    val user = testing.treasury("user");

    val royaltyParams = RoyaltyParams {
        numerator: 10,
        denominator: 100,
        royaltyAddress: deployer.address,
    };

    val nftCollection = NftCollection.fromStorage({
        adminAddress: deployer.address,
        nextItemIndex: 0,
        content: CollectionContent {
            collectionMetadata: createEmptyCell(),
            commonContent: "https://cats.game/metadata/",
        }.toCell(),
        nftItemCode: build("NftItem"),
        royaltyParams: royaltyParams.toCell(),
    });

    val deployRes = nftCollection.deploy(deployer.address, { value: ton("0.05"), bounce: false });

    expect(deployRes).toHaveSuccessfulDeploy({
        to: nftCollection.address,
    });

    return (nftCollection, deployer, user);
}
