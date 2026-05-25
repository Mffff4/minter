import "@acton/io"
import "@acton/build"
import "@acton/emulation/network"
import "@acton/emulation/scripts"
import "@contracts/types"
import "@wrappers/NftCollection.gen"

fun main() {
    val deployer = scripts.wallet("deployer");

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

    val res = nftCollection.deploy(deployer.address, { value: ton("0.05") });
    println(res.waitForTrace());

    println("Deployed NFT Collection to {}", nftCollection.address);
}
