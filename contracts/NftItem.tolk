import "errors"
import "fees-management"
import "messages"
import "types"

struct HeroPropertiesReply {
    level: int
    xpInvested: int
    freeStatPoints: int
    isTransferable: int
    specialStats: SpecialStats
}

contract NftItem {
    author: "Artem"
    version: "1.0.0"
    description: "NFT Hero Item. TEP-62 compliant"
    storage: NftItemStorage
    storageAtDeployment: NftItemStorageNotInitialized
    incomingMessages: AllowedMessageToNftItem
}

type AllowedMessageToNftItem =
    | AskToChangeOwnership
    | RequestStaticData
    | UpdateHero

fun onInternalMessage(in: InMessage) {
    var loadingStorage = NftItemStorage.startLoading();
    if (loadingStorage.isNotInitialized()) {
        assert (
            in.senderAddress == loadingStorage.collectionAddress
        ) throw Errors.NotFromCollection;

        // Initialize from collection
        val initParams = HeroInitParams.fromSlice(in.body);
        val storage: NftItemStorage = {
            itemIndex: loadingStorage.itemIndex,
            collectionAddress: loadingStorage.collectionAddress,
            ownerAddress: initParams.ownerAddress,
            content: initParams.content,
            level: initParams.level,
            xpInvested: initParams.xpInvested,
            freeStatPoints: initParams.freeStatPoints,
            isTransferable: initParams.isTransferable,
            specialStats: initParams.specialStats,
        };
        storage.save();
        return;
    }

    var storage = loadingStorage.endLoading();

    val msg = lazy AllowedMessageToNftItem.fromSlice(in.body);

    match (msg) {
        AskToChangeOwnership => {
            assert (in.senderAddress == storage.ownerAddress) throw Errors.NotFromOwner;
            assert (storage.isTransferable) throw Errors.TransferIsLocked;

            // forwardPayload validation
            val (fwdBits, fwdRefs) = msg.forwardPayload.remainingBitsAndRefsCount();
            assert (fwdBits != 0) throw Errors.IncorrectForwardPayload;
            if (msg.forwardPayload.preloadUint(1) != 0) {
                assert (fwdBits == 1 && fwdRefs == 1) throw Errors.IncorrectForwardPayload;
            }
            assert (msg.newOwnerAddress.getWorkchain() == BASECHAIN) throw Errors.InvalidWorkchain;

            val fwdFee = in.originalForwardFee;
            var restAmount = contract.getOriginalBalance() - MIN_TONS_FOR_STORAGE;
            if (msg.forwardTonAmount != 0) {
                restAmount -= (msg.forwardTonAmount + fwdFee);
            }
            if (msg.sendExcessesTo != null) {
                assert (
                    msg.sendExcessesTo.getWorkchain() == BASECHAIN
                ) throw Errors.InvalidWorkchain;
                restAmount -= fwdFee;
            }

            assert (restAmount >= 0) throw Errors.TooSmallRestAmount;

            if (msg.forwardTonAmount != 0) {
                val ownershipMsg = createMessage({
                    bounce: BounceMode.NoBounce,
                    dest: msg.newOwnerAddress,
                    value: msg.forwardTonAmount,
                    body: NotificationForNewOwner {
                        queryId: msg.queryId,
                        oldOwnerAddress: storage.ownerAddress,
                        payload: msg.forwardPayload,
                    },
                });
                ownershipMsg.send(SEND_MODE_PAY_FEES_SEPARATELY);
            }
            if (msg.sendExcessesTo != null) {
                val excessesMsg = createMessage({
                    bounce: BounceMode.NoBounce,
                    dest: msg.sendExcessesTo,
                    value: restAmount,
                    body: ReturnExcessesBack { queryId: msg.queryId },
                });
                excessesMsg.send(SEND_MODE_PAY_FEES_SEPARATELY);
            }

            storage.ownerAddress = msg.newOwnerAddress;
            storage.save();
        }

        UpdateHero => {
            assert (in.senderAddress == storage.collectionAddress) throw Errors.NotFromCollection;

            storage.level = msg.level;
            storage.xpInvested = msg.xpInvested;
            storage.freeStatPoints = msg.freeStatPoints;
            storage.specialStats = msg.specialStats;
            storage.save();

            // Return excesses back to sendExcessesTo
            val excessesMsg = createMessage({
                bounce: BounceMode.NoBounce,
                dest: msg.sendExcessesTo,
                value: 0,
                body: ReturnExcessesBack { queryId: msg.queryId },
            });
            excessesMsg.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }

        RequestStaticData => {
            val respondMsg = createMessage({
                bounce: BounceMode.NoBounce,
                dest: in.senderAddress,
                value: 0,
                body: UnsafeBodyNoRef {
                    forceInline: ResponseStaticData {
                        queryId: msg.queryId,
                        itemIndex: storage.itemIndex as uint256,
                        collectionAddress: storage.collectionAddress,
                    },
                },
            });
            respondMsg.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }

        else => {
            assert (in.body.isEmpty()) throw 0xFFFF;
        }
    }
}

get fun get_nft_data(): NftDataReply {
    var loadingStorage = NftItemStorage.startLoading();
    if (loadingStorage.isNotInitialized()) {
        return {
            isInitialized: false,
            itemIndex: loadingStorage.itemIndex,
            collectionAddress: loadingStorage.collectionAddress,
        };
    }

    val storage = loadingStorage.endLoading();
    return {
        isInitialized: true,
        itemIndex: storage.itemIndex,
        collectionAddress: storage.collectionAddress,
        ownerAddress: storage.ownerAddress,
        content: storage.content,
    };
}

get fun get_hero_properties(): HeroPropertiesReply {
    var loadingStorage = NftItemStorage.startLoading();
    assert (!loadingStorage.isNotInitialized()) throw 0xFFFF;

    val storage = loadingStorage.endLoading();
    val stats = SpecialStats.fromCell(storage.specialStats);
    return {
        level: storage.level,
        xpInvested: storage.xpInvested,
        freeStatPoints: storage.freeStatPoints,
        isTransferable: storage.isTransferable ? 1 : 0,
        specialStats: stats,
    };
}
