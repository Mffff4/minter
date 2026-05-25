import "@stdlib/strings"
import "errors"
import "fees-management"
import "messages"
import "types"

const MINT_PRICE = ton("1.0")

contract NftCollection {
    author: "Artem"
    version: "1.0.0"
    description: "NFT Hero Collection. TEP-62 and TEP-64 compliant"
    storage: NftCollectionStorage
    incomingMessages: AllowedMessageToNftCollection
}

fun deployNftItem(
    itemIndex: int,
    nftItemCode: cell,
    attachTonAmount: coins,
    initParams: Cell<HeroInitParams>,
) {
    val deployMsg = createMessage({
        bounce: BounceMode.Only256BitsOfBody,
        dest: calcDeployedNftItem(itemIndex, contract.getAddress(), nftItemCode),
        value: attachTonAmount,
        body: initParams,
    });
    deployMsg.send(SEND_MODE_PAY_FEES_SEPARATELY);
}

fun generateSpecialStats(): Cell<SpecialStats> {
    random.initialize();
    
    var strength = 1;
    var perception = 1;
    var endurance = 1;
    var charisma = 1;
    var intelligence = 1;
    var agility = 1;
    var luck = 1;
    
    var remainingPoints = 28;
    while (remainingPoints > 0) {
        val idx = random.range(7);
        if (idx == 0) { strength += 1; }
        else if (idx == 1) { perception += 1; }
        else if (idx == 2) { endurance += 1; }
        else if (idx == 3) { charisma += 1; }
        else if (idx == 4) { intelligence += 1; }
        else if (idx == 5) { agility += 1; }
        else { luck += 1; }
        remainingPoints -= 1;
    }
    
    val stats: SpecialStats = {
        strength: strength,
        perception: perception,
        endurance: endurance,
        charisma: charisma,
        intelligence: intelligence,
        agility: agility,
        luck: luck,
    };
    return stats.toCell();
}

type AllowedMessageToNftCollection =
    | RequestRoyaltyParams
    | DeployHero
    | BatchDeployHeroes
    | ChangeCollectionAdmin
    | PublicMintHero
    | AskToUpdateHero
    | UpgradeCollection

fun onInternalMessage(in: InMessage) {
    val msg = lazy AllowedMessageToNftCollection.fromSlice(in.body);

    match (msg) {
        DeployHero => {
            var storage = lazy NftCollectionStorage.load();
            assert (in.senderAddress == storage.adminAddress) throw Errors.NotFromAdmin;
            assert (msg.itemIndex <= storage.nextItemIndex) throw Errors.InvalidItemIndex;

            val isLast = msg.itemIndex == storage.nextItemIndex;
            deployNftItem(msg.itemIndex, storage.nftItemCode, msg.attachTonAmount, msg.initParams);
            if (isLast) {
                storage.nextItemIndex += 1;
                storage.save();
            }
        }

        PublicMintHero => {
            var storage = lazy NftCollectionStorage.load();
            
            // Check enough value sent
            assert (in.valueCoins >= MINT_PRICE + ton("0.15")) throw Errors.InsufficientFunds;

            // Generate pseudo-random SPECIAL stats
            val statsCell = generateSpecialStats();

            // Init params for item
            val itemIndex = storage.nextItemIndex;
            var contentBuilder = StringBuilder.create();
            contentBuilder.appendInt(itemIndex);
            contentBuilder.append(".json");
            val initParams: HeroInitParams = {
                ownerAddress: in.senderAddress,
                content: contentBuilder.build(),
                level: 1,
                xpInvested: 0,
                freeStatPoints: 0,
                isTransferable: true,
                specialStats: statsCell,
            };

            // Reserve collection balance + mint price
            reserveToncoinsOnBalance(MINT_PRICE, RESERVE_MODE_INCREASE_BY_ORIGINAL_BALANCE);

            // Deploy item
            deployNftItem(itemIndex, storage.nftItemCode, ton("0.08"), initParams.toCell());

            // Increment index
            storage.nextItemIndex += 1;
            storage.save();

            // Calculate and return excesses to sender safely (deducting mint price + deploy cost + estimated gas)
            val excessesValue = in.valueCoins - MINT_PRICE - ton("0.08") - ton("0.02");
            if (excessesValue > 0) {
                val excessesMsg = createMessage({
                    bounce: BounceMode.NoBounce,
                    dest: in.senderAddress,
                    value: excessesValue,
                    body: ReturnExcessesBack { queryId: msg.queryId },
                });
                excessesMsg.send(SEND_MODE_PAY_FEES_SEPARATELY);
            }
        }

        AskToUpdateHero => {
            var storage = lazy NftCollectionStorage.load();
            assert (in.senderAddress == storage.adminAddress) throw Errors.NotFromAdmin;

            // Calculate item address
            val nftItemAddress = calcDeployedNftItem(msg.itemIndex, contract.getAddress(), storage.nftItemCode).calculateAddress();

            // Send UpdateHero message carrying all remaining value
            val updateMsg = createMessage({
                bounce: BounceMode.Only256BitsOfBody,
                dest: nftItemAddress,
                value: 0,
                body: UpdateHero {
                    queryId: msg.queryId,
                    level: msg.level,
                    xpInvested: msg.xpInvested,
                    freeStatPoints: msg.freeStatPoints,
                    specialStats: msg.specialStats,
                    sendExcessesTo: msg.sendExcessesTo,
                },
            });
            updateMsg.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }

        RequestRoyaltyParams => {
            val storage = lazy NftCollectionStorage.load();
            val respondMsg = createMessage({
                bounce: BounceMode.NoBounce,
                dest: in.senderAddress,
                value: 0,
                body: ResponseRoyaltyParams {
                    queryId: msg.queryId,
                    royaltyParams: storage.royaltyParams.load(),
                },
            });
            respondMsg.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }

        BatchDeployHeroes => {
            var storage = lazy NftCollectionStorage.load();
            assert (in.senderAddress == storage.adminAddress) throw Errors.NotFromAdmin;

            var counter = 0;
            var r = msg.deployList.findFirst();
            while (r.isFound) {
                counter += 1;
                assert (counter < BATCH_SIZE_LIMIT) throw Errors.BatchLimitExceeded;

                val itemIndex = r.getKey();
                assert (
                    itemIndex <= storage.nextItemIndex
                ) throw (Errors.NotFromAdmin as int) + counter;

                val dictItem = r.loadValue();
                deployNftItem(
                    itemIndex,
                    storage.nftItemCode,
                    dictItem.attachTonAmount,
                    dictItem.initParams,
                );
                if (itemIndex == storage.nextItemIndex) {
                    storage.nextItemIndex += 1;
                }

                r = msg.deployList.iterateNext(r);
            }
            storage.save();
        }

        ChangeCollectionAdmin => {
            var storage = lazy NftCollectionStorage.load();
            assert (in.senderAddress == storage.adminAddress) throw Errors.NotFromAdmin;
            storage.adminAddress = msg.newAdminAddress;
            storage.save();
        }

        UpgradeCollection => {
            var storage = lazy NftCollectionStorage.load();
            assert (in.senderAddress == storage.adminAddress) throw Errors.NotFromAdmin;

            if (msg.newNftItemCode != null) {
                storage.nftItemCode = msg.newNftItemCode as cell;
                storage.save();
            }

            contract.setCodePostponed(msg.newCode);

            val excessesMsg = createMessage({
                bounce: BounceMode.NoBounce,
                dest: in.senderAddress,
                value: 0,
                body: ReturnExcessesBack { queryId: msg.queryId },
            });
            excessesMsg.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }

        else => {
            assert (in.body.isEmpty()) throw 0xFFFF;
        }
    }
}

fun onBouncedMessage(_in: InMessageBounced) {}

get fun get_collection_data(): CollectionDataReply {
    val storage = lazy NftCollectionStorage.load();
    val content = lazy storage.content.load();

    return {
        nextItemIndex: storage.nextItemIndex,
        collectionMetadata: content.collectionMetadata,
        adminAddress: storage.adminAddress,
    };
}

get fun get_nft_address_by_index(itemIndex: int): address {
    val storage = lazy NftCollectionStorage.load();
    val nftDeployed = calcDeployedNftItem(itemIndex, contract.getAddress(), storage.nftItemCode);
    return nftDeployed.calculateAddress();
}

get fun royalty_params(): RoyaltyParams {
    val storage = lazy NftCollectionStorage.load();
    return storage.royaltyParams.load();
}

get fun get_nft_content(
    _itemIndex: int,
    individualNftContent: string,
): Cell<OffchainMetadataReply> {
    val storage = lazy NftCollectionStorage.load();
    val content = lazy storage.content.load();

    var b = StringBuilder.create();
    b.append(content.commonContent);
    b.append(individualNftContent);
    return OffchainMetadataReply { string: b.build() }.toCell();
}
