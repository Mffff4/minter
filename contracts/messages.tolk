import "types"

struct HeroInitParams {
    ownerAddress: address
    content: string
    level: uint32
    xpInvested: uint64
    freeStatPoints: uint32
    isTransferable: bool
    specialStats: Cell<SpecialStats>
}

struct (0x693d3950) RequestRoyaltyParams {
    queryId: uint64
}

struct (0xa8cb00ad) ResponseRoyaltyParams {
    queryId: uint64
    royaltyParams: RoyaltyParams
}

struct (0x00000001) DeployHero {
    queryId: uint64
    itemIndex: uint64
    attachTonAmount: coins
    initParams: Cell<HeroInitParams>
}

struct (0x00000002) BatchDeployHeroes {
    queryId: uint64
    deployList: map<uint64, BatchDeployDictItem>
}

struct BatchDeployDictItem {
    attachTonAmount: coins
    initParams: Cell<HeroInitParams>
}

struct (0x00000003) ChangeCollectionAdmin {
    queryId: uint64
    newAdminAddress: address
}

struct (0x00000004) PublicMintHero {
    queryId: uint64
}

struct (0x00000005) AskToUpdateHero {
    queryId: uint64
    itemIndex: uint64
    level: uint32
    xpInvested: uint64
    freeStatPoints: uint32
    specialStats: Cell<SpecialStats>
    sendExcessesTo: address
}

struct (0x0aa2921a) UpdateHero {
    queryId: uint64
    level: uint32
    xpInvested: uint64
    freeStatPoints: uint32
    specialStats: Cell<SpecialStats>
    sendExcessesTo: address
}

struct (0x2fcb26a2) RequestStaticData {
    queryId: uint64
}

struct (0x8b771735) ResponseStaticData {
    queryId: uint64
    itemIndex: uint256
    collectionAddress: address
}

struct (0b0) PayloadInline {
    value: RemainingBitsAndRefs
}

struct (0b1) PayloadInRef {
    value: Cell<RemainingBitsAndRefs>
}

struct (0x05138d91) NotificationForNewOwner {
    queryId: uint64
    oldOwnerAddress: address
    @abi.clientType(PayloadInline | PayloadInRef)
    payload: RemainingBitsAndRefs
}

struct (0xd53276db) ReturnExcessesBack {
    queryId: uint64
}

struct (0x5fcc3d14) AskToChangeOwnership {
    queryId: uint64
    newOwnerAddress: address
    sendExcessesTo: address?
    customPayload: cell?
    forwardTonAmount: coins
    @abi.clientType(PayloadInline | PayloadInRef)
    forwardPayload: RemainingBitsAndRefs
}
