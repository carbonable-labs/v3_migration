#[starknet::interface]
pub trait IMigrationV3<TContractState> {
    fn migrate_v2(ref self: TContractState, token_ids: Array<u256>);
    fn estimate_v2(self: @TContractState) -> Array<u256>;
}

#[starknet::contract]
pub mod MigrationV3 {
    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl HelloStarknetImpl of super::IMigrationV3<ContractState> {
        fn migrate_v2(ref self: ContractState, token_ids: Array<u256>) {}

        fn estimate_v2(self: @ContractState) -> Array<u256> {
            array![]
        }
    }
}
