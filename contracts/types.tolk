struct RoyaltyParams {
    numerator: uint16
    denominator: uint16
    royaltyAddress: address
}

struct NftCollectionStorage {
    adminAddress: address
    nextItemIndex: uint64
    content: Cell<CollectionContent>
    nftItemCode: cell
    royaltyParams: Cell<RoyaltyParams>
}

struct CollectionContent {
    collectionMetadata: cell
    commonContent: string
}

struct SpecialStats {
    strength: uint8
    perception: uint8
    endurance: uint8
    charisma: uint8
    intelligence: uint8
    agility: uint8
    luck: uint8
}

struct NftItemStorage {
    itemIndex: uint64
    collectionAddress: address
    ownerAddress: address
    content: string
    level: uint32
    xpInvested: uint64
    freeStatPoints: uint32
    isTransferable: bool
    specialStats: Cell<SpecialStats>
}

struct NftItemStorageNotInitialized {
    itemIndex: uint64
    collectionAddress: address
}

struct NftDataReply {
    isInitialized: bool
    itemIndex: int
    collectionAddress: address
    ownerAddress: address? = null
    content: string? = null
}

fun NftCollectionStorage.load(): NftCollectionStorage {
    return NftCollectionStorage.fromCell(contract.getData());
}

fun NftCollectionStorage.save(self) {
    contract.setData(self.toCell());
}

fun NftItemStorage.startLoading(): NftItemStorageLoader {
    return NftItemStorageLoader.fromCell(contract.getData());
}

fun NftItemStorage.save(self) {
    contract.setData(self.toCell());
}

struct NftItemStorageLoader {
    itemIndex: uint64
    collectionAddress: address
    private rest: RemainingBitsAndRefs
}

fun NftItemStorageLoader.isNotInitialized(self): bool {
    return self.rest.isEmpty();
}

fun NftItemStorageLoader.endLoading(mutate self): NftItemStorage {
    val ownerAddress: address = self.rest.loadAny();
    val content: string = self.rest.loadAny();
    val level: uint32 = self.rest.loadAny();
    val xpInvested: uint64 = self.rest.loadAny();
    val freeStatPoints: uint32 = self.rest.loadAny();
    val isTransferable: bool = self.rest.loadAny();
    val specialStats: Cell<SpecialStats> = self.rest.loadAny();
    return {
        itemIndex: self.itemIndex,
        collectionAddress: self.collectionAddress,
        ownerAddress,
        content,
        level,
        xpInvested,
        freeStatPoints,
        isTransferable,
        specialStats,
    };
}

fun calcDeployedNftItem(
    itemIndex: uint64,
    collectionAddress: address,
    nftItemCode: cell,
): AutoDeployAddress {
    val emptyNftItemStorage: NftItemStorageNotInitialized = { itemIndex, collectionAddress };
    return { stateInit: { code: nftItemCode, data: emptyNftItemStorage.toCell() } };
}

struct CollectionDataReply {
    nextItemIndex: int
    collectionMetadata: cell
    adminAddress: address
}

struct (0x01) OffchainMetadataReply {
    string: string
}
