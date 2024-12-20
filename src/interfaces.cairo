use starknet::ContractAddress;

#[starknet::interface]
pub trait IProject<TContractState> {
    fn get_num_vintages(self: @TContractState) -> usize;
    fn batch_mint(
        ref self: TContractState, to: ContractAddress, token_ids: Span<u256>, values: Span<u256>
    );
    fn balance_of(self: @TContractState, owner: ContractAddress, token_id: u256) -> u256;
    fn balance_of_batch(
        self: @TContractState, owners: Span<ContractAddress>, token_ids: Span<u256>
    ) -> Span<u256>;
    fn grant_minter_role(self: @TContractState, minter: ContractAddress);
}
